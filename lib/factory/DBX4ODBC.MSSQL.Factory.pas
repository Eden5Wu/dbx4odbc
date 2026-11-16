{
  DBX4 ODBC SQL Server Factory (adapted from DBExpress.MSSQL.Factory.pas)
  Original source: https://github.com/Eden5Wu/HelperClass
  Copyright (c) 2023 Eden5Wu
  SPDX-License-Identifier: MIT

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

  Native DBX4 ODBC optional application library; not a driver core dependency.
}
unit DBX4ODBC.MSSQL.Factory;

interface

uses
  System.Classes,
  Data.DBXCommon,
  Data.SqlExpr,
  DBX4ODBC.Factory;

type
  // SQL Server-specific convenience layer; all DBX operations are inherited.
  TDBXMSSQLFactory = class(TDBX4ODBCFactory)
  public
    constructor Create(const AHostName, ADatabase, AUserName,
      APassword: string; const OSAuthentication: Boolean = False); overload;
    constructor Create(const AParams: TStrings); overload;
    function PrepareMSQuery(const ASQL: string): TDBXCommand;

    class function OleDBConnectionStringToDBX(AConnection: TSQLConnection;
      AOleDBConnectionString: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  DbxOpenOdbcDriver;

const
  SET_NOCOUNT_ON = 'SET NOCOUNT ON;'#13#10;
  SET_READ_UNCOMMITTED =
    'SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;'#13#10;
  SET_MSQUERY_HEAD = SET_NOCOUNT_ON + SET_READ_UNCOMMITTED;

constructor TDBXMSSQLFactory.Create(const AHostName, ADatabase, AUserName,
  APassword: string; const OSAuthentication: Boolean);
var
  Params: TStringList;
begin
  Params := TStringList.Create;
  try
    Params.Values[TDBXPropertyNames.HostName] := AHostName;
    Params.Values[TDBXPropertyNames.Database] := ADatabase;
    if OSAuthentication then
      Params.Values[TDBXOpenOdbcProperties.StrConnectionString] :=
        'Trusted_Connection=yes'
    else
    begin
      Params.Values[TDBXPropertyNames.UserName] := AUserName;
      Params.Values[TDBXPropertyNames.Password] := APassword;
    end;
    inherited Create(Params);
  finally
    Params.Free;
  end;
end;

constructor TDBXMSSQLFactory.Create(const AParams: TStrings);
begin
  inherited Create(AParams);
  // Backward compatibility with DBExpress.MSSQL.Factory's OS Authentication key.
  if SameText(FConnectionProps['OS Authentication'], 'True') and
     (FConnectionProps[TDBXOpenOdbcProperties.StrConnectionString] = '') then
    FConnectionProps[TDBXOpenOdbcProperties.StrConnectionString] :=
      'Trusted_Connection=yes';
end;

function TDBXMSSQLFactory.PrepareMSQuery(const ASQL: string): TDBXCommand;
begin
  // Retain the legacy API; this alters SQL Server session isolation.
  // Prefer Prepare() when READ UNCOMMITTED is not intentional.
  Result := Prepare(SET_MSQUERY_HEAD + ASQL);
end;

class function TDBXMSSQLFactory.OleDBConnectionStringToDBX(
  AConnection: TSQLConnection; AOleDBConnectionString: string): Boolean;
begin
  AConnection.Close;
  AConnection.DriverName := sDbxOpenOdbcDriverName;
  AConnection.GetDriverFunc := 'getSQLDriverODBCW';
  AConnection.LibraryName := 'DbxOpenOdbcDriver';
  AConnection.VendorLib := 'ODBC32.DLL';
  AConnection.LoginPrompt := False;
  AConnection.Params.Clear;
  AConnection.Params.Values[TDBXOpenOdbcProperties.StrConnectionString] :=
    AOleDBConnectionString;
  AConnection.Open;
  Result := AConnection.Connected;
end;

end.
