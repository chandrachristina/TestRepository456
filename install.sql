-- ATP :: PDT_OIC_DEV2 into PDT_OIC_DEV5
-- PDT_OIC_DEV2 into PDT_OIC_DEV5, generated 2026-11-09 14:01 UTC
--
-- Run against the TARGET database:  sql <user>@<target> @install.sql
-- Drops run first, then creates and alters, then recompiles.

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
SET DEFINE OFF;
SET ECHO OFF;

PROMPT ============================================================
PROMPT Done. Check for invalid objects before signing off:
PROMPT   SELECT object_name, object_type FROM user_objects WHERE status <> 'VALID';
PROMPT ============================================================
