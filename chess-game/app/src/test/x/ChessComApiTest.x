module ChessComApiTest {
    package chess import chess.examples.org;
    package web   import web.xtclang.org;

    import chess.api.ChessComApi;

    import web.responses.SimpleResponse;

    /**
     * Tests for the chess.com proxy (`/api/chesscom`): every path segment the client controls is
     * checked before it is placed in the upstream URL, so a bad value is refused here and never
     * reaches chess.com.
     *
     * Calls that actually reach chess.com live in the opt-in `ChessLiveApiTest`.
     */
    class ChessComApiTests {
        static String bodyOf(SimpleResponse response) = response.body?.bytes.unpackUtf8() : "";

        // ----- refused before reaching chess.com -------------------------------------------------

        @Test
        void shouldRefuseAMalformedUsername() {
            ChessComApi api = new ChessComApi();

            for (String name : ["ab", "has space", "../etc", "semi;colon", "slash/name"]) {
                SimpleResponse player   = api.player(name);
                SimpleResponse archives = api.archives(name);
                assert player.status == BadRequest;
                assert archives.status == BadRequest;
                assert bodyOf(player).indexOf("Invalid username");
            }
        }

        @Test
        void shouldRefuseAMalformedArchiveMonth() {
            ChessComApi api = new ChessComApi();

            assert api.games("hikaru", "26", "10").status == BadRequest;
            assert api.games("hikaru", "2026", "1").status == BadRequest;
            assert api.games("hikaru", "20x6", "10").status == BadRequest;
            assert api.games("hikaru", "2026", "1a").status == BadRequest;
            assert api.games("x", "2026", "10").status == BadRequest;
        }

        // ----- the validation rules themselves ---------------------------------------------------

        @Test
        void shouldAcceptChessComUsernames() {
            assert ChessComApi.isValidUsername("hikaru");
            assert ChessComApi.isValidUsername("Magnus_Carlsen");
            assert ChessComApi.isValidUsername("a-b-c");
            assert ChessComApi.isValidUsername("abc");
            assert ChessComApi.isValidUsername("abcdefghijklmnopqrstuvwxy"); // 25, the maximum
        }

        @Test
        void shouldRejectAnythingThatCouldAlterTheUpstreamPath() {
            assert !ChessComApi.isValidUsername("ab");                         // too short
            assert !ChessComApi.isValidUsername("abcdefghijklmnopqrstuvwxyz"); // 26, too long
            assert !ChessComApi.isValidUsername("../admin");
            assert !ChessComApi.isValidUsername("name?x=1");
            assert !ChessComApi.isValidUsername("name%2F");
            assert !ChessComApi.isValidUsername("naïve");
        }

        @Test
        void shouldRequireExactlyTheRightNumberOfDigits() {
            assert ChessComApi.isDigits("2026", 4);
            assert ChessComApi.isDigits("09", 2);
            assert !ChessComApi.isDigits("202", 4);
            assert !ChessComApi.isDigits("20266", 4);
            assert !ChessComApi.isDigits("20a6", 4);
            assert !ChessComApi.isDigits("", 2);
        }
    }
}
