program FactoryUsage;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Data.DBXCommon,
  OdbcApi in '..\..\source\OdbcApi.pas',
  DbxOpenOdbcDialects in '..\..\source\DbxOpenOdbcDialects.pas',
  DbxOpenOdbcCore in '..\..\source\DbxOpenOdbcCore.pas',
  DbxOpenOdbcDriver in '..\..\source\DbxOpenOdbcDriver.pas',
  DBX4ODBC.Factory in '..\..\lib\factory\DBX4ODBC.Factory.pas';

var
  Factory: TDBX4ODBCFactory;
  Cmd: TDBXCommand;
  Reader: TDBXReader;
begin
  if ParamCount < 2 then
  begin
    Writeln('Usage: FactoryUsage.exe "ODBC connection string" "SELECT ..."');
    Writeln('The SQL statement is DBMS-specific; no credentials are hardcoded.');
    Halt(2);
  end;

  try
    Factory := TDBX4ODBCFactory.Create(ParamStr(1));
    try
      Cmd := Factory.Prepare(ParamStr(2));
      try
        Reader := Factory.ExecuteQuery(Cmd);
        try
          while Reader.Next do
          begin
            if Reader.ColumnCount > 0 then
              Writeln(Reader.Value[0].AsString);
          end;
        finally
          Reader.Free;
        end;
      finally
        Cmd.Free;
      end;
    finally
      Factory.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
