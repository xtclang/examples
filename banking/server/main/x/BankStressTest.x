/**
 * This is a test app for the Bank demo.
 */
@WebApp
module BankStressTest
    {
    package web import web.xtclang.org;

    package Bank import Bank;

    import Bank.Account;
    import Bank.Connection;

    import Bank.oodb.DBClosed;
    import Bank.oodb.CommitFailed;

    import web.*;

    static Duration TEST_DURATION = Duration:30s;
    static Int      BRANCHES      = 24;
    static Int      MAX_ACCOUNTS  = 100;

    @WebService("/stress")
    service Test
        {
        Branch[] branches = [];

        @Get("run")
        @Produces(Text)
        String run()
            {
            for (Branch branch : branches)
                {
                if (branch.status == Open)
                    {
                    return "Bank is already open";
                    }
                }

            branches = new Branch[BRANCHES](i -> new Branch(i.toUInt64()));
            for (Branch branch : branches)
                {
                branch.doBusiness^(TEST_DURATION);
                }

            private void checkOpen(Branch[] branches, Timer timer)
                {
                for (Branch branch : branches)
                    {
                    // wait until all branches are closed
                    if (branch.status == Open)
                        {
                        timer.schedule(Duration.ofSeconds(10), &checkOpen(branches, timer));
                        return;
                        }
                    }
                @Inject Connection bank;
                bank.log.add("All branches have closed");
                }

            // schedule a periodic check
            @Inject Timer timer;
            timer.schedule(Duration.ofSeconds(10), &checkOpen(branches, timer));
            return "Bank is open";
            }

        @Get("report")
        @Produces(Text)
        String report()
            {
            StringBuffer buf = new StringBuffer();
            for (Branch branch : branches)
                {
                if (branch.status == Open)
                    {
                    buf.append($"Branch {branch.branchId} performed {branch.totalTx} transactions");
                    }
                else
                    {
                    buf.append($"Branch {branch.branchId} is closed");
                    }
                buf.append('\n');
                }
            return buf.size == 0 ? "Not started" : buf.truncate(-1);
            }
        }

    @StaticContent("/", /webapp)
    service Content
        {
        }

    service Branch(UInt64 branchId)
        {
        @Inject Connection bank;
        @Inject Clock      clock;

        enum Status {Initial, Open, Closed}
        @Atomic public/private Status status = Initial;

        @Atomic public/private Int totalTx;

        @Concurrent
        void doBusiness(Duration duration)
            {
            Int    tryCount = 0;
            Int    txCount  = 0;
            Time   start    = clock.now;
            Time   close    = start + duration;
            Random rnd      = new ecstasy.numbers.PseudoRandom(branchId);

            status = Open;
            bank.log.add($"Branch {branchId} opened");

            business:
            while (True)
                {
                if (++tryCount % 100 == 0)
                    {
                    Time now = clock.now;
                    if (now < close)
                        {
                        bank.log.add(
                            $|Branch {branchId} performed {100 + txCount} transactions in \
                             |{(now - start).seconds} seconds
                             );
                        txCount = 0;
                        start   = now;
                        }
                    else
                        {
                        break business;
                        }
                    }

                String op = "";
                try
                    {
                    Int acctId = rnd.int(MAX_ACCOUNTS);
                    switch (rnd.int(100))
                        {
                        case 0..1:
                            op = "OpenAccount";
                            if (!bank.accounts.contains(acctId))
                                {
                                txCount++;
                                totalTx++;
                                bank.openAccount(acctId, 256_00);
                                }
                            break;

                        case 2..3:
                            op = "CloseAccount";
                            if (bank.accounts.contains(acctId))
                                {
                                txCount++;
                                totalTx++;
                                bank.closeAccount(acctId);
                                }
                            break;

                        case 4..49:
                            op = "Deposit or Withdrawal";
                            if (Account acc := bank.accounts.get(acctId))
                                {
                                txCount++;
                                totalTx++;
                                Int amount = rnd.boolean() ? acc.balance/2 : -acc.balance/2;
                                bank.depositOrWithdraw(acctId, amount);
                                }
                            break;

                        case 50..98:
                            op = "Transfer";
                            Int acctIdTo = rnd.int(MAX_ACCOUNTS);
                            if (acctIdTo != acctId,
                                    Account accFrom := bank.accounts.get(acctId),
                                    bank.accounts.contains(acctIdTo),
                                    accFrom.balance > 100)
                                {
                                txCount++;
                                totalTx++;
                                bank.transfer(acctId, acctIdTo, accFrom.balance / 2);
                                }
                            break;

                        case 99:
                            op = "Audit";
                            txCount++;
                            totalTx++;
                            bank.log.add($"Branch {branchId} audited amount is {Bank.format(bank.audit())}");
                            break;
                        }
                    }
                catch (Exception e)
                    {
                    bank.log.add($"{op} failed at {branchId}: {e.text}");
                    if (op == "Audit"
                            || e.is(DBClosed)
                            || e.is(CommitFailed) && e.result == DatabaseError
                            )
                        {
                        break business;
                        }
                    }
                }

            bank.log.add($"Branch {branchId} closed");
            status = Closed;
            }
        }
    }