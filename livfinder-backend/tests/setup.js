// Tests run against the real database but must not shout. NODE_ENV=test also
// disables the rate limiter, so one suite cannot lock out the next.
process.env.NODE_ENV = "test";
process.env.LOG_LEVEL = process.env.LOG_LEVEL || "silent";
