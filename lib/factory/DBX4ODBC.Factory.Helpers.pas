{
  DBX4 ODBC Factory Library (adapted from DBExpress.MSSQL.Factory.pas)
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
unit DBX4ODBC.Factory.Helpers;

interface

uses
  Data.DBXCommon,
  System.SysUtils,
  System.Classes,
  Data.SqlTimSt;

type
  TDBXCommandHelper = class helper for TDBXCommand
    /// <seealso>https://forums.devart.com/viewtopic.php?t=22342</seealso>
    /// <code>
    /// DBXPar := DBXCmd.CreateParameter;
    /// DBXPar.DataType := TDBXDataTypes.BlobType;
    /// DBXPar.Value.SetStream(TFileStream.Create(sArqXml, fmOpenRead), True);
    /// DBXPar.Value.ValueType.ValueTypeFlags := DBXPar.Value.ValueType.ValueTypeFlags or TDBXValueTypeFlags.ExtendedType;
    ///
    /// DBXCmd.Parameters.AddParameter(DBXPar);
    /// </code>
    function CreateBlobParameter: TDBXParameter;
    function ExecuteSmartQuery: TDBXReader;
  end;

  TDBXParameterHelper = class helper for TDBXParameter
  private
    function GetAsString: string;
    procedure SetAsString(const AValue: string);
    function GetAsAnsiString: AnsiString;
    procedure SetAsAnsiString(const AValue: AnsiString);
    function GetAsDouble: Double;
    procedure SetAsDouble(const AValue: Double);
    function GetAsInt32: TInt32;
    procedure SetAsInt32(const AValue: TInt32);
    function GetAsBoolean: Boolean;
    procedure SetAsBoolean(const AValue: Boolean);
    function GetAsDateTime: TDateTime;
    procedure SetAsDateTime(const AValue: TDateTime);
  public
    procedure Clear;

    property AsDouble: Double read GetAsDouble write SetAsDouble;
    property AsString: string read GetAsString write SetAsString;
    property AsAnsiString: AnsiString read GetAsAnsiString write SetAsAnsiString;
    property AsInt32: TInt32 read GetAsInt32 write SetAsInt32;
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsDateTime: TDateTime read GetAsDateTime write SetAsDateTime;
  end;

implementation

{ TDBXCommandHelper }

function TDBXCommandHelper.CreateBlobParameter: TDBXParameter;
begin
  Result := TDBXParameter.Create(FDbxContext);
  Result.DataType := TDBXDataTypes.BlobType;
  Result.ValueTypeFlags := Result.ValueTypeFlags or TDBXValueTypeFlags.ExtendedType;
end;

function TDBXCommandHelper.ExecuteSmartQuery: TDBXReader;
begin
  try
    Result := Self.ExecuteQuery;
    while (Result <> nil) and (Result.ColumnCount = 0) do
    begin
      Result.Free;
      Result := Self.GetNextReader;
    end;
  except
    // 1. Catch DBX-specific errors first
    on E: TDBXError do
    begin
      // When E.ErrorCode is $FFFF, 實務上 OLE DB 驅動回傳的通用錯誤碼（通常是 SQL 語法或命令錯誤）
      if E.ErrorCode = $FFFF then
      begin
        raise Exception.Create(Format('SQL 語法或資料庫引擎錯誤 (SQL Syntax / Engine Error)!'#13#10 +
                                      '詳細訊息 (Detailed Message): %s'#13#10 +
                                      '出錯的 SQL (Offending SQL): %s', [E.Message, Self.Text]));
      end
      // When E.ErrorCode is $0065 (101), 符合 DBX 官方規格定義的資料庫廠商原生錯誤
      else if (E.ErrorCode = TDBXErrorCodes.VendorError) then
      begin
        raise Exception.Create(Format('Database driver error (Vendor Error)！'#13#10 +
                                    'Detailed Message: %s', [E.Message]));
      end
      else
      begin
        raise Exception.Create(Format('DBX System Error (Code: $%x): %s', [E.ErrorCode, E.Message]));
      end;

      // 💡 Highly recommended to log the offending SQL syntax to a log file here
      // LogError(Command.Text, E.Message);
    end;

    // 2. Catch other unexpected system errors (e.g., memory issues, null pointers, etc.)
    on E: Exception do
    begin
      raise;
    end;
  end;
end;

{ TDBXParameterHelper }

procedure TDBXParameterHelper.Clear;
begin
  Value.SetNull;
end;

function TDBXParameterHelper.GetAsAnsiString: AnsiString;
begin
  Result := Value.GetAnsiString;
end;

function TDBXParameterHelper.GetAsBoolean: Boolean;
begin
  Result := Value.GetBoolean;
end;

function TDBXParameterHelper.GetAsDateTime: TDateTime;
begin
  Result := Value.AsDateTime;
end;

function TDBXParameterHelper.GetAsDouble: Double;
begin
  Result := Value.GetDouble;
end;

function TDBXParameterHelper.GetAsInt32: TInt32;
begin
  Result := Value.GetInt32;
end;

function TDBXParameterHelper.GetAsString: string;
begin
  Result := Value.GetWideString;
end;

procedure TDBXParameterHelper.SetAsAnsiString(const AValue: AnsiString);
begin
  DataType := TDBXDataTypes.AnsiStringType;
  Value.SetAnsiString(AValue);
end;

procedure TDBXParameterHelper.SetAsBoolean(const AValue: Boolean);
begin
  DataType := TDBXDataTypes.BooleanType;
  Value.SetBoolean(AValue);
end;

procedure TDBXParameterHelper.SetAsDateTime(const AValue: TDateTime);
begin
  DataType := TDBXDataTypes.TimeStampType;
  Value.SetTimeStamp(DateTimeToSQLTimeStamp(AValue));
end;

procedure TDBXParameterHelper.SetAsDouble(const AValue: Double);
begin
  DataType := TDBXDataTypes.DoubleType;
  Value.SetDouble(AValue);
end;

procedure TDBXParameterHelper.SetAsInt32(const AValue: TInt32);
begin
  DataType := TDBXDataTypes.Int32Type;
  Value.SetInt32(AValue);
end;

procedure TDBXParameterHelper.SetAsString(const AValue: string);
begin
  DataType := TDBXDataTypes.WideStringType;
  Value.SetWideString(AValue);
end;

end.
