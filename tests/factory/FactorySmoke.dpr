program FactorySmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  Data.DBXCommon,
  OdbcApi in '..\..\source\OdbcApi.pas',
  DbxOpenOdbcDialects in '..\..\source\DbxOpenOdbcDialects.pas',
  DbxOpenOdbcCore in '..\..\source\DbxOpenOdbcCore.pas',
  DbxOpenOdbcDriver in '..\..\source\DbxOpenOdbcDriver.pas',
  DBX4ODBC.Factory in '..\..\lib\factory\DBX4ODBC.Factory.pas',
  DBX4ODBC.Factory.Helpers in '..\..\lib\factory\DBX4ODBC.Factory.Helpers.pas',
  DBX4ODBC.MSSQL.Factory in '..\..\lib\factory\DBX4ODBC.MSSQL.Factory.pas';

procedure AssertEqual(const Expected, Actual, Context: string);
begin
  if Expected <> Actual then
    raise Exception.CreateFmt('%s: expected "%s", got "%s"',
      [Context, Expected, Actual]);
end;

procedure TestGenericFactory;
var
  Factory: TDBX4ODBCFactory;
  ConnString: string;
begin
  ConnString := 'Driver={SQLite3 ODBC Driver};Database=:memory:;';
  Factory := TDBX4ODBCFactory.Create(ConnString);
  try
    AssertEqual(sDbxOpenOdbcDriverName,
      Factory.ConnectionProps[TDBXPropertyNames.DriverName], 'generic driver');
    AssertEqual(ConnString,
      Factory.ConnectionProps[TDBXOpenOdbcProperties.StrConnectionString],
      'generic connection string');
  finally
    Factory.Free;
  end;
end;

procedure TestMsSqlFactory;
var
  Factory: TDBXMSSQLFactory;
  Params: TStringList;
begin
  Factory := TDBXMSSQLFactory.Create('server01', 'erp', 'app', 'secret');
  try
    AssertEqual('server01',
      Factory.ConnectionProps[TDBXPropertyNames.HostName], 'SQL Server host');
    AssertEqual('erp',
      Factory.ConnectionProps[TDBXPropertyNames.Database], 'SQL Server database');
    AssertEqual('app',
      Factory.ConnectionProps[TDBXPropertyNames.UserName], 'SQL Server username');
    AssertEqual(sDbxOpenOdbcDriverName,
      Factory.ConnectionProps[TDBXPropertyNames.DriverName], 'SQL Server driver');
  finally
    Factory.Free;
  end;

  Factory := TDBXMSSQLFactory.Create('server01', 'erp', '', '', True);
  try
    AssertEqual('Trusted_Connection=yes',
      Factory.ConnectionProps[TDBXOpenOdbcProperties.StrConnectionString],
      'integrated auth');
  finally
    Factory.Free;
  end;

  // Ensure the base class also honors explicit property lists and retains the
  // original connection string (rather than reserializing semicolon tokens).
  Params := TStringList.Create;
  try
    Params.Values[TDBXPropertyNames.DriverName] := 'MSSQL';
    Params.Values[TDBXOpenOdbcProperties.StrConnectionString] :=
      'Driver={PostgreSQL Unicode};Server=localhost;Database=testdb;';
    with TDBX4ODBCFactory.Create(Params) do
    try
      AssertEqual(sDbxOpenOdbcDriverName,
        ConnectionProps[TDBXPropertyNames.DriverName], 'generic params driver');
      AssertEqual(Params.Values[TDBXOpenOdbcProperties.StrConnectionString],
        ConnectionProps[TDBXOpenOdbcProperties.StrConnectionString],
        'generic params connection string');
    finally
      Free;
    end;
  finally
    Params.Free;
  end;

  Params := TStringList.Create;
  try
    Params.Values[TDBXPropertyNames.DriverName] := 'MSSQL';
    Params.Values['OS Authentication'] := 'True';
    Factory := TDBXMSSQLFactory.Create(Params);
    try
      AssertEqual(sDbxOpenOdbcDriverName,
        Factory.ConnectionProps[TDBXPropertyNames.DriverName],
        'legacy driver name override');
      AssertEqual('Trusted_Connection=yes',
        Factory.ConnectionProps[TDBXOpenOdbcProperties.StrConnectionString],
        'legacy integrated auth');
    finally
      Factory.Free;
    end;
  finally
    Params.Free;
  end;
end;

begin
  try
    TestGenericFactory;
    TestMsSqlFactory;
    Writeln('FactorySmoke: PASS (offline constructor/property checks)');
  except
    on E: Exception do
    begin
      Writeln('FactorySmoke: FAIL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
