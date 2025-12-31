/**
 * Tests for the Bank database.
 *
 * To run it from banking/server directory, use the following commands:
 *      xtc build -L build -o build main/x/BankTest.x
 *      xtc test -L build BankTest
 *
 * Temporary test databases will be created under "banking/server/xunit/test-output" directory.
 */
module BankTest {
    package Bank    import Bank;
    package xunit   import xunit.xtclang.org;
    package xunitdb import xunit_db.xtclang.org;

    import Bank.Account;
    import Bank.Connection;

    import xunit.annotations.AfterEach;
    import xunit.annotations.BeforeEach;

    import xunit.assertions.assertThrows;

    import xunitdb.DatabaseTest;

    @DatabaseTest(Shared)
    class BankOpeningTests {

        @Inject Connection bank;

        @Test
        void shouldHaveNoAccounts() {
            assert bank.accounts.empty;
        }

        @Test
        void shouldHaveNoHoldings() {
            assert bank.holding.get() == 0;
        }
    }

    class FormatAmountTests {
        @Test
        void shouldFormatAmountWithDollarsAndCents() {
            assert Bank.format(1234) == "$12.34";
        }

        @Test
        void shouldFormatNegativeAmountWithDollarsAndCents() {
            assert Bank.format(-1234) == "$-12.34";
        }

        @Test
        void shouldFormatZero() {
            assert Bank.format(0) == "$0.00";
        }

        @Test
        void shouldFormatNegativeZero() {
            assert Bank.format(-0) == "$0.00";
        }

        @Test
        void shouldFormatAmountWithZeroCents() {
            assert Bank.format(1000) == "$10.00";
        }

        @Test
        void shouldFormatAmountOnlyCents() {
            assert Bank.format(99) == "$0.99";
        }

        @Test
        void shouldFormatAmountOnlyNegativeCents() {
            assert Bank.format(-99) == "$-0.99";
        }
    }

    class AccountTests {
        @Test
        void shouldChangeBalanceByPositiveAmount() {
            Account account  = new Account(1, 1000);
            Account adjusted = account.changeBalance(100);
            assert account != adjusted;
            assert adjusted.balance == 1100;
        }

        @Test
        void shouldChangeBalanceByNegativeAmount() {
            Account account  = new Account(1, 2000);
            Account adjusted = account.changeBalance(-100);
            assert account != adjusted;
            assert adjusted.balance == 1900;
        }
    }

    @DatabaseTest(PerTest)
    class OpenAccountTests {

        @Inject Connection bank;

        @Test
        void ShouldOpenAccount() {
            Account account = bank.openAccount(19, 200676);
            assert account.id == 19;
            assert account.balance == 200676;
            assert Account fromDb := bank.accounts.get(account.id);
            assert fromDb == account;
        }

        @Test
        void ShouldAdjustHoldingWhenOpeningAccount() {
            Int openingBalance = 100220000;
            Int holdingBefore  = bank.holding.get();
            bank.openAccount(19, openingBalance);
            assert bank.holding.get() == (holdingBefore + openingBalance);
        }

        @Test
        void ShouldNotOpenAccountWithExistingId() {
            bank.openAccount(1, 1000);
            IllegalState thrown = assertThrows(() -> bank.openAccount(1, 2000));
            assert thrown.message == "account 1 already exists";
        }

        @Test
        void ShouldNotOpenAccountWithZeroBalance() {
            IllegalState thrown = assertThrows(() -> bank.openAccount(1, 0));
            assert thrown.message == "invalid opening balance: $0.00";
        }

        @Test
        void ShouldNotOpenAccountWithNegativeBalance() {
            IllegalState thrown = assertThrows(() -> bank.openAccount(1, -100));
            assert thrown.message == "invalid opening balance: $-1.00";
        }

        @Test
        void shouldRollbackAccountOpening() {
            Int holdingBefore = bank.holding.get();
            Int accountId     = 76;
            using (var tx = bank.createTransaction()) {
                bank.openAccount(accountId, 200676);
                assert bank.accounts.get(accountId);
                tx.rollback();
            }
            assert bank.holding.get() == holdingBefore;
            assert bank.accounts.get(accountId) == False;
        }
    }

    @DatabaseTest(PerTest)
    class CloseAccountTests {

        @Inject Connection bank;

        @Test
        void ShouldCloseAccount() {
            Account account = bank.openAccount(19, 200676);
            bank.closeAccount(account.id);
            assert bank.accounts.get(account.id) == False;
        }

        @Test
        void ShouldAdjustHoldingWhenClosingAccount() {
            Int holdingBefore = bank.holding.get();
            bank.openAccount(19, 200676);
            bank.closeAccount(19);
            assert bank.holding.get() == holdingBefore;
        }

        @Test
        void ShouldNotCloseNonExistentAccount() {
            IllegalState thrown = assertThrows(() -> bank.closeAccount(1));
            assert thrown.message == "account 1 doesn't exist";
        }
    }

    @DatabaseTest(Shared)
    class DepositOrWithdrawTests {

        @Inject Connection bank;

        Int accountId      = 19;
        Int openingBalance = 1000;

        @BeforeEach
        void setup() {
            bank.openAccount(accountId, openingBalance);
        }

        @AfterEach
        void cleanup() {
            bank.closeAccount(accountId);
        }

        @Test
        void shouldDepositAmount() {
            using (bank.createTransaction()) {
                bank.depositOrWithdraw(accountId, 100);
            }
            assert Account account := bank.accounts.get(accountId);
            assert account.balance == openingBalance + 100;
        }

        @Test
        void shouldUpdateBankHoldingOnDeposit() {
            Int holdingBefore = bank.holding.get();
            using (bank.createTransaction()) {
                bank.depositOrWithdraw(accountId, 100);
            }
            assert bank.holding.get() == holdingBefore + 100;
        }

        @Test
        void shouldWithdrawAmount() {
            using (bank.createTransaction()) {
                bank.depositOrWithdraw(accountId, -100);
            }
            assert Account account := bank.accounts.get(accountId);
            assert account.balance == openingBalance - 100;
        }

        @Test
        void shouldUpdateBankHoldingOnWithdrawal() {
            Int holdingBefore = bank.holding.get();
            using (bank.createTransaction()) {
                bank.depositOrWithdraw(accountId, -100);
            }
            assert bank.holding.get() == holdingBefore - 100;
        }

        @Test
        void shouldNotWithdrawMoreThanBalance() {
            Int tooMuch = openingBalance + 1;
            IllegalState thrown = assertThrows(() -> bank.depositOrWithdraw(accountId, -tooMuch));
            assert thrown.message == "not enough funds to withdraw $10.01 from account 19";
        }

        @Test
        void shouldNotWithdrawFromNonExistentAccount() {
            IllegalState thrown = assertThrows(() -> bank.depositOrWithdraw(100, 10));
            assert thrown.message == "account 100 doesn't exist";
        }
    }

    @DatabaseTest(Shared)
    class TransferTests {

        @Inject Connection bank;

        Int accountIdOne      = 19;
        Int openingBalanceOne = 1000;
        Int accountIdTwo      = 20;
        Int openingBalanceTwo = 5000;

        @BeforeEach
        void setup() {
            bank.openAccount(accountIdOne, openingBalanceOne);
            bank.openAccount(accountIdTwo, openingBalanceTwo);
        }

        @AfterEach
        void cleanup() {
            bank.closeAccount(accountIdOne);
            bank.closeAccount(accountIdTwo);
        }

        @Test
        void shouldTransferAmountBetweenAccounts() {
            Int amount = 100;
            bank.transfer(accountIdOne, accountIdTwo, amount);
            assert Account accountOne := bank.accounts.get(accountIdOne);
            assert Account accountTwo := bank.accounts.get(accountIdTwo);
            assert accountOne.balance == openingBalanceOne - amount;
            assert accountTwo.balance == openingBalanceTwo + amount;
        }

        @Test
        void shouldTransferFullBalanceBetweenAccounts() {
            Int amount = openingBalanceOne;
            bank.transfer(accountIdOne, accountIdTwo, amount);
            assert Account accountOne := bank.accounts.get(accountIdOne);
            assert Account accountTwo := bank.accounts.get(accountIdTwo);
            assert accountOne.balance == 0;
            assert accountTwo.balance == openingBalanceTwo + amount;
        }

        @Test
        void shouldNotAdjustBankHoldingAfterTransfer() {
            Int amount = 100;
            Int holdingBefore = bank.holding.get();
            bank.transfer(accountIdOne, accountIdTwo, amount);
            assert bank.holding.get() == holdingBefore;
        }

        @Test
        void shouldNotTransferToSameAccount() {
            IllegalState thrown = assertThrows(() ->
                    bank.transfer(accountIdOne, accountIdOne, 10));
            assert thrown.message == "invalid transfer within an account";
        }

        @Test
        void shouldNotTransferFromNonExistentAccount() {
            IllegalState thrown = assertThrows(() ->
                    bank.transfer(100, accountIdOne, 10));
            assert thrown.message == "account 100 doesn't exist";
        }

        @Test
        void shouldNotTransferToNonExistentAccount() {
            IllegalState thrown = assertThrows(() ->
                    bank.transfer(accountIdOne, 100, 10));
            assert thrown.message == "account 100 doesn't exist";
        }

        @Test
        void shouldNotTransferNegativeAmount() {
            IllegalState thrown = assertThrows(() ->
                    bank.transfer(accountIdOne, accountIdTwo, -500));
            assert thrown.message == "invalid transfer amount: $-5.00";
        }

        @Test
        void shouldNotTransferMoreThanAccountBalance() {
            Int          amount = openingBalanceOne + 1;
            IllegalState thrown = assertThrows(() ->
                    bank.transfer(accountIdOne, accountIdTwo, amount));
            assert thrown.message == "not enough funds to transfer $10.01 from account 19";
        }
    }

    @DatabaseTest(PerTest)
    class AuditTests {

        @Inject Connection bank;

        Int totalAccounts = 10;
        Int totalBalance  = 0;

        @BeforeEach
        void setup() {
            Random rnd = new ecstasy.numbers.PseudoRandom();
            for (Int i : 0 ..< totalAccounts) {
                Int amount = rnd.int(1000);
                bank.openAccount(i, amount);
                totalBalance += amount;
            }
        }

        @Test
        void shouldSuccessfullyAudit() {
            assert bank.audit() == totalBalance;
        }

        @Test
        void shouldFailAuditWhenHoldingDoesNotMatchTotalAccounts() {
            // force an incorrect holding value
            Int holding = totalBalance - 1;
            bank.holding.set(holding);

            IllegalState thrown = assertThrows(() -> bank.audit());
            assert thrown.message ==
                    $"audit failed: expected={Bank.format(totalBalance)}, actual={Bank.format(holding)}";
        }

        @Test
        void shouldFailAuditIfAccountHasNegativeBalance() {
            // force an account to have a negative balance
            assert Account account := bank.accounts.get(totalAccounts / 2);
            bank.accounts.put(account.id, new Account(account.id, -100));

            IllegalState thrown = assertThrows(() -> bank.audit());
            assert thrown.message == $"audit failed: negative balance for account {account.id}";
       }
    }
}
