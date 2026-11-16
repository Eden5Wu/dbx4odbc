# MSSQL factory adapter for native DBX4 ODBC

This optional helper is adapted from
[`DBExpress.MSSQL.Factory.pas`](https://github.com/Eden5Wu/HelperClass/blob/master/DBExpress.MSSQL.Factory.pas)
(MIT license, copyright 2023 Eden5Wu).

- **New unit:** `DBX4ODBC.MSSQL.Factory.pas`
- **Factory class:** `TDBXMSSQLFactory` (original API retained)
- **Driver:** `DbxOpenOdbcDriver` (pure Pascal native DBX4; no `dbxmss.dll` or `sqlncli10.dll`)
- **Placement:** demo helper under `demos/dbms/mssql/`, *not* a mandatory fifth `source/` driver unit
- **Compatibility:** targets the supported DBX4 Delphi editions; needs a SQL Server ODBC driver installed on Windows

## Using it

Include `source/` and `demos/dbms/mssql/` in Delphi's **Search Path**.
Use the new unit name in your `uses` clause:

```delphi
uses
  System.SysUtils, Data.DBXCommon,
  DBX4ODBC.MSSQL.Factory;

var
  Factory: TDBXMSSQLFactory;
  Cmd: TDBXCommand;
  Reader: TDBXReader;
begin
  Factory := TDBXMSSQLFactory.Create(
    '127.0.0.1', 'YourDatabase', 'YourUser', 'YourPassword');
  try
    Cmd := Factory.Prepare('SELECT TOP (1) name FROM sys.tables');
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

For Windows Integrated Authentication, pass `OSAuthentication=True`:

```delphi
Factory := TDBXMSSQLFactory.Create('localhost', 'YourDatabase', '', '', True);
```

For an existing OLE DB connection string, use the `TStrings` constructor:

```delphi
Params := TStringList.Create;
try
  Params.Values['ConnectionString'] :=
    'Provider=SQLOLEDB;Data Source=localhost;Initial Catalog=YourDatabase;Integrated Security=SSPI;';
  Factory := TDBXMSSQLFactory.Create(Params);
  try
    Factory.GetConnection;
  finally
    Factory.Free;
  end;
finally
  Params.Free;
end;
```

The OODBC driver translates the OLE DB string, detects an installed SQL Server
ODBC driver, and applies its own protocol/MARS logic. The helper also retains
`OleDBConnectionStringToDBX` for a caller-managed `TSQLConnection`.

## Differences from the HelperClass original

1. `TDBXMSSQLFactory.Create(host, database, user, password)` passes discrete
   `HostName`, `Database`, `User_Name`, and `Password` properties to
   `DbxOpenOdbcDriver`; it no longer chooses the old MSSQL native driver.
2. `Create(AParams)` forces `DriverName=DbxOpenOdbc` and recognizes the
   legacy `OS Authentication=True` flag when no explicit connection string is set.
3. `OleDBConnectionStringToDBX` passes the **whole** OLE DB string to
   `ConnectionString` instead of splitting on semicolons and hardcoding old DLLs.
4. The metadata helper opens its DBX connection on first use.
5. `Execute(SQL, args)` binds parameters once rather than twice.

The original `PrepareMSQuery` method remains for source compatibility but
prepends `SET NOCOUNT ON` and `READ UNCOMMITTED`. The native driver already
handles non-row SQL results, so prefer `Prepare` unless those isolation semantics
are intentional.

This adapter is not yet verified by a Delphi compilation or live SQL Server
integration test. The original HelperClass unit and native driver core were
left unchanged.
