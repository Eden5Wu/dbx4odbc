# DBX4 ODBC Factory 函式庫（選用）

[English Documentation](README.md)

本目錄提供可直接整合至 Delphi 正式專案的**應用層 Factory 函式庫**，並非展示用 Demo。
使用者可選擇直接操作原生 DBX4 API，或在 `source/` 四個核心 Driver 單元之上引用這套封裝。

Factory **不是** OODBC Driver 的必要相依項，也不會改變 `source/` 的四單元架構。

## 1. 元件與定位

| 單元 | 主要類別 | 用途 |
| --- | --- | --- |
| `DBX4ODBC.Factory.pas` | `TDBX4ODBCFactory` | 跨 DBMS 的 DBX Connection、Command、參數與 Metadata 管理 |
| `DBX4ODBC.MSSQL.Factory.pas` | `TDBXMSSQLFactory` | SQL Server 專屬連線便利介面、相容 `PrepareMSQuery` 與 OLE DB 連線字串轉換 |
| `DBX4ODBC.Factory.Helpers.pas` | `TDBXCommandHelper`、`TDBXParameterHelper` | 可選用的共用 DBX Class Helpers，避免在各 DBMS Factory 重複定義 |

`TDBXMSSQLFactory` 繼承 `TDBX4ODBCFactory`，沿用通用資料庫操作 API，僅保留 SQL Server 必要的特殊行為。

PostgreSQL、SQLite、MySQL、Oracle、Firebird 等資料庫，原則上直接使用通用 Factory 即可；不必為了連線而各自建立一個子類別。底層資料庫差異仍由 `DbxOpenOdbcDialects.pas` 和 ODBC Driver 處理。

### 授權與來源

本 Factory 與 Helpers 改寫自 [HelperClass／`DBExpress.MSSQL.Factory.pas`](https://github.com/Eden5Wu/HelperClass/blob/master/DBExpress.MSSQL.Factory.pas)，Copyright (c) 2023 Eden5Wu，採 **MIT License**，授權聲明保留於各原始碼檔案開頭。

`source/` 的原生 Driver 核心則維持 **LGPL 2.1 or later**，兩者的授權條款須分別遵循。

## 2. 安裝與引用

將以下兩個目錄加入 Delphi 專案的 **Search Path**：

```text
source/
lib/factory/
```

也可以直接把實際需要的 `.pas` 單元加入專案。

目前 `boss.json` 的 `mainsrc` 仍為 `source/`：使用 Boss 安裝時，Factory 檔案可以隨儲存庫下載，但**不會自動成為專案的必要編譯單元**。需要使用 Factory 時，另外加入 `lib/factory/` 的搜尋路徑即可。

## 3. 跨資料庫通用 Factory

以下使用 PostgreSQL 示範。相同的 `TDBX4ODBCFactory` 也可以連線其他 ODBC 資料庫，只需調整連線字串與 SQL。

```delphi
uses
  Data.DBXCommon, DBX4ODBC.Factory;

var
  Factory: TDBX4ODBCFactory;
  Cmd: TDBXCommand;
  Reader: TDBXReader;
begin
  Factory := TDBX4ODBCFactory.Create(
    'Driver={PostgreSQL Unicode};Server=localhost;Port=5432;' +
    'Database=app;Uid=app;Pwd=secret;');
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

原本的 `demos/connections/` 繼續負責展示各 DBMS 的連線設定，**不是 Factory 的執行階段相依項**。使用 Factory 時，不必額外引用那些 Demo 單元。

### 通用 API

| 方法／屬性 | 用途 |
| --- | --- |
| `Create(ConnectionString)` | 以 ODBC 連線字串建立 Factory |
| `Create(Params)` | 以 `TStrings` 屬性建立 Factory |
| `GetConnection` | 延遲建立並取得受管理的 `TDBXConnection` |
| `Prepare(SQL)` | 建立並 Prepare `TDBXCommand` |
| `Execute(SQL)`、`Execute(SQL, Args)` | 執行不回傳資料列的 SQL |
| `Execute(Command)`、`Execute(Command, Args)` | 使用呼叫端提供的 Command 執行 |
| `ExecuteQuery(Command)`、`ExecuteQuery(Command, Args)` | 執行查詢並回傳 `TDBXReader` |
| `FillParameters` | 將 Variant 清單轉入 DBX Parameters |
| `DBXGetTableList` | 透過 DBX Metadata 取得資料表名稱 |
| `ConnectionProps` | 存取連線屬性；建議在首次連線前完成設定 |

`Execute(SQL, Args)` 等多載接收**一維 Variant 陣列**，並檢查 Prepare 後的參數數量；`FillParameters` 也要求來源與目標參數數量一致。參數無效時會拋出例外，不會靜默略過。

參數型別已由 Prepare 確定時，可以使用 `Null` Variant 表示 SQL NULL；實際欄位型別和支援情況仍取決於 DBX 與 ODBC Driver。

## 4. SQL Server Factory

保留既有 `TDBXMSSQLFactory` 的使用方式，讓原本使用 `DBExpress.MSSQL.Factory` 的程式能較容易遷移至 OODBC。

```delphi
uses
  DBX4ODBC.MSSQL.Factory;

var
  Factory: TDBXMSSQLFactory;
begin
  Factory := TDBXMSSQLFactory.Create(
    'localhost', 'MyDatabase', 'sa', 'password');
  try
    Factory.Execute('UPDATE dbo.Tasks SET Flag = 1 WHERE Id = 123');
  finally
    Factory.Free;
  end;
end;
```

使用 Windows 整合驗證：

```delphi
Factory := TDBXMSSQLFactory.Create(
  'localhost', 'MyDatabase', '', '', True);
```

仍提供 `Create(Params: TStrings)` 多載，並相容既有的 `OS Authentication=True` 設定。

對於以 `Provider=` 開頭的 OLE DB 連線字串，轉換工作交由 OODBC 核心處理；需要操作呼叫端自己管理的 `TSQLConnection` 時，仍可使用 `OleDBConnectionStringToDBX`。

### `PrepareMSQuery` 的特別語意

此方法為了相容原本的 MSSQL Factory，會在 SQL 前加上：

```sql
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
```

其中 `READ UNCOMMITTED` 會改變 SQL Server 連線的交易隔離行為。若無此需求，應使用一般的 `Prepare`；目前 OODBC Driver 已自行處理多陳述式 SQL 的部分非資料列結果，不必一律透過 `PrepareMSQuery`。

## 5. 物件所有權與多執行緒

- **Factory 擁有 Connection 與連線屬性**：第一次呼叫 `GetConnection` 時才建立 DBX 連線，釋放 Factory 時一併釋放 Connection。
- **呼叫端擁有 Command 與 Reader**：`Prepare` 回傳的 `TDBXCommand` 和 `ExecuteQuery` 回傳的 `TDBXReader` 均由呼叫端釋放。
- **釋放順序**：`Reader → Command → Factory`。Reader 可能依賴 Command 的游標，不可提前釋放 Command。
- **執行 SQL 字串時**：`Execute(SQL)` 與 `Execute(SQL, Args)` 會自行建立與釋放 Command；傳入既有 Command 的多載則不接管所有權。
- **執行緒模型**：一個 Factory 實例代表一個 Session，不視為可供多執行緒同時共用的 Singleton。不同執行緒各自建立 Factory 實例。
- **交易控制**：Factory 不會隱含開始、Commit 或 Rollback 交易；由應用程式透過 `GetConnection` 取得 DBX Connection，再使用目標 Delphi 版本提供的交易 API 控制。
- **Connection Pooling**：由原生 OODBC Driver 的 `Pooling` 設定處理；Factory 不重複實作另一套連線池。

## 6. Demo、測試與驗證狀態

| 檔案 | 用途 |
| --- | --- |
| [`demos/factory/FactoryUsage.dpr`](../../demos/factory/FactoryUsage.dpr) | 接受 ODBC ConnectionString 與 SQL，展示跨 DBMS 查詢 |
| [`tests/factory/FactorySmoke.dpr`](../../tests/factory/FactorySmoke.dpr) | 離線檢查通用／MSSQL Factory 建構與設定值，不需要連線資料庫 |

**目前已完成原始碼整理、GitHub 提交與靜態結構檢查；尚未完成 Delphi Win32／Win64 編譯、Smoke Test 實際執行及跨 DBMS 連線整合測試。**

Factory 目前仍在 Pull Request 階段，相關項目應完成驗證後再合併至正式分支。
