BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "push_subscriptions" (
    "id" bigserial PRIMARY KEY,
    "pubKey" text NOT NULL,
    "relay" text NOT NULL,
    "token" text NOT NULL,
    "transport" text NOT NULL,
    "kinds" json
);

-- Indexes
CREATE UNIQUE INDEX "push_subscription_unique_idx" ON "push_subscriptions" USING btree ("pubKey", "relay", "token");


--
-- MIGRATION VERSION FOR maps_api
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('maps_api', '20261119102017524', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261119102017524', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20261015164015382', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015164015382', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
