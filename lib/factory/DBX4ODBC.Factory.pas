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
unit DBX4ODBC.Factory;

interface

uses
  System.Classes,
  System.Variants,
  System.Generics.Collections,
  Data.DBXCommon,
  Data.DBXMetaDataProvider,
  Data.DBXDataExpressMetaDataProvider,
  Data.DBXTypedTableStorage,
  DbxOpenOdbcDriver;

type
  // Each instance owns one lazily opened TDBXConnection and is not thread-safe.
  // Callers own the TDBXCommand and TDBXReader returned by the API.
  TDBX4ODBCFactory = class
  protected
    FDBXConnection: TDBXConnection;
    FConnectionProps: TDBXProperties;
    FConnectionFactory: TDBXConnectionFactory;
  private
    function DBXGetMetaProvider: TDBXMetaDataProvider;
    function DBXGetTables(const AProvider: TDBXMetaDataProvider): TDBXTablesTableStorage;
  public
    constructor Create(const AConnectionString: string); overload;
    constructor Create(const AParams: TStrings); overload;
    destructor Destroy; override;

    function GetConnection: TDBXConnection;
    function Prepare(const ASQL: string): TDBXCommand;
    function Execute(const ASQL: string): Int64; overload;
    function Execute(const ASQL: string; const Args: OleVariant): Int64; overload;
    function Execute(ASQLCommand: TDBXCommand): Int64; overload;
    function Execute(ASQLCommand: TDBXCommand; const Args: OleVariant): Int64; overload;
    function ExecuteQuery(ASQLCommand: TDBXCommand): TDBXReader; overload;
    function ExecuteQuery(ASQLCommand: TDBXCommand; const Args: OleVariant): TDBXReader; overload;
    function FillParameters(AParams: TDBXParameterList;
      AVariableList: TList<Variant>): Boolean;
    function DBXGetTableList(const ATableType: string = ''): TStrings;

    property ConnectionProps: TDBXProperties read FConnectionProps;
  end;

implementation

uses
  System.SysUtils;

procedure FillDBXParamFromVariable(AParam: TDBXParameter; const AValue: Variant);
begin
  case VarType(AValue) and varTypeMask of
    varEmpty, varNull:
      AParam.Value.SetNull;
    varInteger:
      begin
        AParam.DataType := TDBXDataTypes.Int32Type;
        AParam.Value.AsInt32 := AValue;
      end;
    varOleStr, varString, varUString:
      begin
        AParam.DataType := TDBXDataTypes.WideStringType;
        AParam.Value.AsString := AValue;
      end;
    varBoolean:
      begin
        AParam.DataType := TDBXDataTypes.BooleanType;
        AParam.Value.AsBoolean := AValue;
      end;
    varDouble:
      begin
        AParam.DataType := TDBXDataTypes.DoubleType;
        AParam.Value.AsDouble := AValue;
      end;
    varDate:
      begin
        AParam.DataType := TDBXDataTypes.DateTimeType;
        AParam.Value.AsDateTime := AValue;
      end;
    varSmallint:
      begin
        AParam.DataType := TDBXDataTypes.Int16Type;
        AParam.Value.AsInt16 := AValue;
      end;
    varSingle:
      begin
        AParam.DataType := TDBXDataTypes.SingleType;
        AParam.Value.AsSingle := AValue;
      end;
    varCurrency:
      begin
        AParam.DataType := TDBXDataTypes.CurrencyType;
        AParam.Value.AsCurrency := AValue;
      end;
    varShortInt:
      begin
        AParam.DataType := TDBXDataTypes.Int8Type;
        AParam.Value.AsInt8 := AValue;
      end;
    varWord:
      begin
        AParam.DataType := TDBXDataTypes.UInt16Type;
        AParam.Value.AsUInt16 := AValue;
      end;
    varInt64:
      begin
        AParam.DataType := TDBXDataTypes.Int64Type;
        AParam.Value.AsInt64 := AValue;
      end;
  else
    raise Exception.CreateFmt('Unsupported DBX parameter Variant type: %d',
      [VarType(AValue)]);
  end;
end;

procedure FillParams(ASQLCommand: TDBXCommand; const Args: OleVariant);
var
  LowBound, HighBound, I: Integer;
begin
  ASQLCommand.Prepare;
  if VarIsEmpty(Args) or VarIsNull(Args) then
    Exit;
  if (not VarIsArray(Args)) or (VarArrayDimCount(Args) <> 1) then
    raise Exception.Create('SQL parameter arguments must be a one-dimensional Variant array');
  LowBound := VarArrayLowBound(Args, 1);
  HighBound := VarArrayHighBound(Args, 1);
  if HighBound - LowBound + 1 <> ASQLCommand.Parameters.Count then
    raise Exception.CreateFmt('SQL parameter count mismatch: expected %d, got %d',
      [ASQLCommand.Parameters.Count, HighBound - LowBound + 1]);
  for I := LowBound to HighBound do
    FillDBXParamFromVariable(ASQLCommand.Parameters[I - LowBound], Args[I]);
end;

constructor TDBX4ODBCFactory.Create(const AConnectionString: string);
begin
  inherited Create;
  FConnectionProps := TDBXProperties.Create;
  try
    FConnectionProps[TDBXPropertyNames.DriverName] := sDbxOpenOdbcDriverName;
    FConnectionProps[TDBXOpenOdbcProperties.StrConnectionString] := AConnectionString;
    FConnectionFactory := TDBXConnectionFactory.GetConnectionFactory;
  except
    FConnectionProps.Free;
    raise;
  end;
end;

constructor TDBX4ODBCFactory.Create(const AParams: TStrings);
begin
  inherited Create;
  FConnectionProps := TDBXProperties.Create;
  try
    if AParams <> nil then
      FConnectionProps.MergeProperties(AParams);
    // A DBMS factory never selects a vendor's native DBX DLL.
    FConnectionProps[TDBXPropertyNames.DriverName] := sDbxOpenOdbcDriverName;
    FConnectionFactory := TDBXConnectionFactory.GetConnectionFactory;
  except
    FConnectionProps.Free;
    raise;
  end;
end;

destructor TDBX4ODBCFactory.Destroy;
begin
  // Never close the connection while client-owned readers/commands are alive.
  FDBXConnection.Free;
  FConnectionProps.Free;
  inherited;
end;

function TDBX4ODBCFactory.GetConnection: TDBXConnection;
begin
  if FDBXConnection = nil then
    FDBXConnection := FConnectionFactory.GetConnection(FConnectionProps);
  Result := FDBXConnection;
end;

function TDBX4ODBCFactory.Prepare(const ASQL: string): TDBXCommand;
begin
  Result := GetConnection.CreateCommand;
  try
    Result.CommandType := TDBXCommandTypes.DbxSQL;
    Result.Text := ASQL;
    Result.Prepare;
  except
    Result.Free;
    raise;
  end;
end;

function TDBX4ODBCFactory.Execute(const ASQL: string): Int64;
var
  Cmd: TDBXCommand;
begin
  Cmd := GetConnection.CreateCommand;
  try
    Cmd.CommandType := TDBXCommandTypes.DbxSQL;
    Cmd.Text := ASQL;
    Result := Execute(Cmd);
  finally
    Cmd.Free;
  end;
end;

function TDBX4ODBCFactory.Execute(const ASQL: string;
  const Args: OleVariant): Int64;
var
  Cmd: TDBXCommand;
begin
  Cmd := GetConnection.CreateCommand;
  try
    Cmd.CommandType := TDBXCommandTypes.DbxSQL;
    Cmd.Text := ASQL;
    Result := Execute(Cmd, Args);
  finally
    Cmd.Free;
  end;
end;

function TDBX4ODBCFactory.Execute(ASQLCommand: TDBXCommand): Int64;
begin
  ASQLCommand.ExecuteUpdate;
  Result := ASQLCommand.RowsAffected;
end;

function TDBX4ODBCFactory.Execute(ASQLCommand: TDBXCommand;
  const Args: OleVariant): Int64;
begin
  FillParams(ASQLCommand, Args);
  Result := Execute(ASQLCommand);
end;

function TDBX4ODBCFactory.ExecuteQuery(ASQLCommand: TDBXCommand): TDBXReader;
begin
  Result := ASQLCommand.ExecuteQuery;
end;

function TDBX4ODBCFactory.ExecuteQuery(ASQLCommand: TDBXCommand;
  const Args: OleVariant): TDBXReader;
begin
  FillParams(ASQLCommand, Args);
  Result := ExecuteQuery(ASQLCommand);
end;

function TDBX4ODBCFactory.FillParameters(AParams: TDBXParameterList;
  AVariableList: TList<Variant>): Boolean;
var
  I: Integer;
begin
  if (AParams = nil) or (AVariableList = nil) then
    raise Exception.Create('Parameter list cannot be nil');
  if AParams.Count <> AVariableList.Count then
    raise Exception.CreateFmt('SQL parameter count mismatch: expected %d, got %d',
      [AParams.Count, AVariableList.Count]);
  for I := 0 to AParams.Count - 1 do
    FillDBXParamFromVariable(AParams[I], AVariableList[I]);
  Result := True;
end;

function TDBX4ODBCFactory.DBXGetMetaProvider: TDBXMetaDataProvider;
var
  Provider: TDBXDataExpressMetaDataProvider;
begin
  Provider := TDBXDataExpressMetaDataProvider.Create;
  try
    Provider.Connection := GetConnection;
    Provider.Open;
  except
    Provider.Free;
    raise;
  end;
  Result := Provider;
end;

function TDBX4ODBCFactory.DBXGetTables(
  const AProvider: TDBXMetaDataProvider): TDBXTablesTableStorage;
begin
  Result := AProvider.GetCollection(TDBXMetaDataCommands.GetTables)
    as TDBXTablesTableStorage;
end;

function TDBX4ODBCFactory.DBXGetTableList(
  const ATableType: string): TStrings;
var
  Provider: TDBXMetaDataProvider;
  Tables: TDBXTablesTableStorage;
begin
  Result := TStringList.Create;
  try
    Provider := DBXGetMetaProvider;
    try
      Tables := DBXGetTables(Provider);
      try
        while Tables.InBounds do
        begin
          if (ATableType = '') or SameText(Tables.TableType, ATableType) then
            Result.Add(Tables.TableName);
          Tables.Next;
        end;
      finally
        Tables.Free;
      end;
    finally
      Provider.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
