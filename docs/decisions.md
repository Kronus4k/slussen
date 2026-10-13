# Decisions log

D0.x decisions are in the project context file. Day decisions continue here.

| ID | Decision | Why | Alternative rejected |
| --- | --- | --- | --- |
| D1.1 | Repo `slussen`, project folder outside cloud-synced folders | No file locks on venv or Docker files | Documents (OneDrive-synced) |
| D1.2 | Python 3.13 for `venv-pipeline`, alongside system default 3.14 | Broader library support (Snowflake connector, pyarrow, Airflow providers) and a supported Lambda runtime | Python 3.14 (too new for some dependencies) |