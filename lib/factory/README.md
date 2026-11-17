# Optional application Factory library

[繁體中文說明文件](README_TW.md)

This directory is **not** a demo. Units here can be added to a Delphi
application's Search Path in addition to the four mandatory driver source
units in `source/`. The Factory is optional; applications may use the
native DBX4 APIs directly.

## Modules

| Unit | Public API | Role |
| --- | --- | --- |
| `DBX4ODBC.Factory.pas` | `TDBX4ODBCFactory` | DBMS-neutral DBX connection, commands, parameters and metadata |
| `DBX4ODBC.MSSQL.Factory.pas` | `TDBXMSSQLFactory` | SQL Server connection convenience, legacy `PrepareMSQuery` and OLE DB conversion |
| `DBX4ODBC.Factory.Helpers.pas` | `TDBXCommandHelper`, `TDBXParameterHelper` | Optional DBX class helpers shared by every database |

The Factory and Helpers were adapted from the original
[`DBExpress.MSSQL.Factory.pas`](https://github.com/Eden5Wu/HelperClass/blob/master/DBExpress.MSSQL.Factory.pas),
copyright (c) 2023 Eden5Wu, **MIT license**; see the source file headers.
The native driver core in `source/` remains LGPL-2.1-or-later.

## DBMS-neutral usage

```delphi
uses
  Data.DBXCommon, DBX4ODBC.Factory;

var
  Factory: TDBX4ODBCFactory;
  Cmd: TDBXCommand;
  Reader: TDBXReader;
begin
  Factory := TDBX4ODBCFactory.Create(
    'Driver={PostgreSQL Unicode};Server=localhost;Port=5432;Database=app;Uid=app;Pwd=secret;');
  try
    Cmd := Factory.Prepare('SELECT CURRENT_DATE');
    try
      Reader := Factory.ExecuteQuery(Cmd);
      try
        while Reader.Next do
          Writeln(Reader.Value[0].AsString);
      finally
        Reader.Free;
      end;
    finally
      Cmd.Free;
    end;
  finally
    Factory.Free;
  end;
end;
```

The same base Factory accepts SQL Server, SQLite, MySQL, Oracle, Firebird
or any ODBC-compliant database **without creating a derived Factory**.
Only the ODBC connection string and SQL vary. The existing
`demos/connections/` units remain connection examples, not runtime
dependencies.

## SQL Server compatibility

```delphi
uses DBX4ODBC.MSSQL.Factory;
var Factory: TDBXMSSQLFactory;
begin
  Factory := TDBXMSSQLFactory.Create('localhost', 'MyDatabase', 'sa', 'password');
  try
    Factory.Execute('UPDATE dbo.Tasks SET Flag = 1 WHERE Id = 123');
  finally
    Factory.Free;
  end;
end;
```

Windows authentication:
`TDBXMSSQLFactory.Create('localhost', 'MyDatabase', '', '', True)`.

`TDBXMSSQLFactory.Create(Params)` preserves the old `TStrings` constructor,
including the optional `OS Authentication=True` key. Connection strings
starting with `Provider=` are translated by the native ODBC driver.
`OleDBConnectionStringToDBX` remains available for a caller-owned
`TSQLConnection`.

`PrepareMSQuery` prepends `SET NOCOUNT ON` and
`SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED`. Those are legacy
SQL Server semantics and should be chosen deliberately; regular `Prepare`
does not apply them.

## Ownership and concurrency contracts

- **Factory owns** its connection and properties, opens the connection lazily,
  and closes it when destroyed. Treat each instance as a **single-threaded
  session**, not a shared thread-safe singleton.
- **Caller owns** commands returned by `Prepare` and readers returned by
  `ExecuteQuery`. Free **Reader → Command → Factory**, in that order.
- A `TDBXReader` may depend on the originating command/cursor;
  do not release the command before the reader.
- `Execute(SQL)` and `Execute(SQL, Args)` create/free their own commands.
  `Execute(Command)` and `ExecuteQuery(Command)` never take ownership
  of the supplied command.
- `Args` is a one-dimensional Variant array; count is checked against
  prepared DBX parameters. `FillParameters` requires equal list counts;
  invalid arguments raise exceptions rather than silently succeeding.
  SQL NULL is supported via a `Null` Variant when the prepared parameter type is known.
- Transaction scope is controlled using the standard
  `Factory.GetConnection.BeginTransaction / CommitFreeAndNil / RollbackFreeAndNil`
  APIs as available in the target RAD Studio version. The Factory itself
  does not implicitly start or commit transactions.
- Delphi's native `DBXPool` is unsupported. Leave `DelegateConnection=DBXPool`
  unset. To pool connections, use `Pooling=True` and configure the driver in
  Windows ODBC Data Source Administrator. On PostgreSQL, the next borrower
  may get the same connection with your temporary tables and settings still
  there. Drop the tables and restore any settings you changed before closing
  the connection. [Pooling setup](../../README.md#47-pooling-windows-odbc-driver-manager-native-connection-pooling)

## Installation and tests

For non-SQL Server DBMSs, specify `Driver=` or `DSN=` explicitly. A connection
string containing other keys without either one selects a SQL Server ODBC
driver.

Add `source/` and `lib/factory/` to the project Search Path (or include
specific `.pas` files in the project). Boss's `mainsrc` remains `source/`
so the four-unit driver is still lightweight; `lib/factory/` is optional.

- `tests/factory/FactorySmoke.dpr` runs offline constructor and property checks.
  Set `DBXOODBC_FACTORY_TEST_CONNECTION` in the test process to also run a live,
  read-only parameterized query.
- `demos/factory/FactoryUsage.dpr`: live generic SQL execution example.
