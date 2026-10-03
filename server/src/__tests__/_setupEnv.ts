/**
 * Imported first (for its side effects) by every test file, before any
 * module that transitively imports ../firebaseAdmin. That file throws at
 * import time if FIREBASE_SERVICE_ACCOUNT_BASE64 is unset, and
 * initializeApp() needs a syntactically valid credential even though no
 * test here ever makes a real network call to Firebase — every test
 * monkey-patches ../db, ../status, and ../drive directly instead (see
 * README note at the top of ingestTelemetry.test.ts). The key below is
 * never used to sign anything for real.
 */

const fakeServiceAccount = {
  type: "service_account",
  project_id: "test-project",
  private_key_id: "test",
  // A throwaway RSA key generated locally purely so firebase-admin's PEM
  // parser doesn't reject it at init time — never used to sign anything
  // real, and not tied to any actual Google account.
  private_key:
    "-----BEGIN PRIVATE KEY-----\n" +
    "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDDAjBtqpUPPmAA\n" +
    "vmR1WCCSz3u76eZ64arynmcbwEvKSs04aLrIv3rAUcF0I3cKOiOHFcKF5uEc+zbB\n" +
    "UXL+7EhQmu3jXTLVpZQUuNXwp9K7Wv2bWqwL4oplrwQuQsvmnIwO1PLSt4ystZrX\n" +
    "5LRCLRQT/77MA+aCFoG3towvxLJpmwg3MAcEBc/QGMuNU3yWetuUlzHQakd10Ltn\n" +
    "+KPHJNoJ/pTGaggCKT4SsawykVkE1klUcfbZydEn0N/TG3Hw5OQegAhGwGbdMeru\n" +
    "/CVopSxUUe6BMMFjwbLW2H9zIfVaXqL9aNuotb1dmnFoZLss7hDKHlfgPKlAqUe7\n" +
    "br/83EJDAgMBAAECggEAGi5tj75ivoYFKqRlOrycZvQ0rGvWALJ9RTn6JZIsOsUk\n" +
    "h18cO2k7KEicXKTe+GsKK7qYABVELPlssQi9PoznlUGFEHe0pFV+K51jRSkAVHIo\n" +
    "xsD7hKmjeM0ba8CWZ+hQWjTB7djXKgrvIUQ4kAKbBaevl0GAzaoK5r47VQsnWaEg\n" +
    "YKEtap2mKFHL7wIPf8snGSq11AtIJUGTVIfYf6HYteKMWUW7YdqR6osCIGeeD8Le\n" +
    "QGOT2I/QHyexj3rBPdt4XpzdWoeYVt0jl9fHNnakgucpcWQzEJSE+s4Jq/H9pVXH\n" +
    "QSrdlLTjv9IDOm8fvE5aY+dHjwK3lzgzmI5rnqZpfQKBgQDlGbjQ8v6eB6NGZBNk\n" +
    "bT0wnGwYvhrxnY51UzxLOEf/FIc1nHtx984raqe4WZh4lmn3qBGpigPAxCMbJKON\n" +
    "36lWdQSvwNGSlrGCPTn+pkChWbM8jhHqrdkDahtXIF+eMBN9NhdGAQme9Mst7SBU\n" +
    "s3Pt2XBABfGG0ProAxtLNdxbzQKBgQDZ57xZRbi/POSOzVIeTekRebugVxntJqc0\n" +
    "sZwOA1fgnauPmiNxItcjwEqjyn2Mv6Xm7UbrcAfCb4uNKeYHDO4dq0TpFCjKL4C4\n" +
    "dootIj6sA8ebWeh7NEoPEHqYHtM6M5sn05VffjLX6Bxqqfzsj04nbsRY0BjyrJec\n" +
    "1LeYYKmmTwKBgGovyeHPPwSwNZVivTpHB52IYvH06zgh9u2abs/OflBUi3bl2LGy\n" +
    "UfT9sk9X97usu+D2HXmfZq3qOvtRuB0CFdLk2g88J+bxwcTD7CWDmWEv2kuu7c8A\n" +
    "VR2oCJQRhUAkuGPItnDT+kma3LGkvt+DbbBIoCaMmq4KHsF67yOlC0XhAoGBAK06\n" +
    "cJ13s/sz6W8tAs9cmKBv6hz5oX7Kb7qQR8NMHRxPvAeZPfu++tFNGQlE/LJb2QPQ\n" +
    "NcUNdt2313UNjfSk7tdfRJUWlabGRMpgUlC3HKObDaAOxabMVuPK8erk9n8ab4ol\n" +
    "xmX36WuC9rRFFvDoq/TlNep05KBnXNAsuxfEIJo5AoGAXW3xoQAUu4Oz0sIUjJyR\n" +
    "Rbse0BPFvQS/89yD2LkZLcuzjLhzOs63FDSNCfqXy85wVbYosYfi6SDKKeEzSDZb\n" +
    "vGrp/PPouTTeQOPksZlGKumh20uQeqki9SZ72HNZ0fKax1ltejIWM130XdW47DZ/\n" +
    "OIi8fMKekCocfujMIUz4+vQ=\n" +
    "-----END PRIVATE KEY-----\n",
  client_email: "test@test-project.iam.gserviceaccount.com",
  client_id: "123",
  token_uri: "https://oauth2.googleapis.com/token",
};

process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 = Buffer.from(
  JSON.stringify(fakeServiceAccount)
).toString("base64");
process.env.EMQX_WEBHOOK_SECRET = "test-emqx-secret";
process.env.DRIVE_WEBHOOK_SECRET = "test-drive-secret";
process.env.TAILSCALE_WEBHOOK_SECRET = "test-tailscale-secret";
process.env.TAILSCALE_IMAGE_BASE_URL = "http://test-tailnet.example.ts.net:5000";
process.env.PUBLIC_BASE_URL = "http://test-backend.example.com";
