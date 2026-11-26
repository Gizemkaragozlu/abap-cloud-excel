# abap-cloud-xlsx

ABAP Cloud / S/4HANA Public Cloud için XLSX ve CSV yükleme–indirme kütüphanesi.
Amaç: `GUI_UPLOAD`, `abap2xlsx` ve `CL_FDT_XL_SPREADSHEET` olmadan, Fiori/RAP tarafından
gelen dosya akışını (`xstring`) doğrudan tipli internal table'a çevirmek.

> **Kısaca:** Excel'den gelen `xstring` → başlık eşleme → tip dönüşümü → doğrulama raporu →
> toplu sipariş tablosu. GUI'de `GUI_UPLOAD` ile yapılan işin cloud uyumlu karşılığı.

## Neden XCO?

SAP'in yayınlanmış (released) XCO kütüphanesinde XLSX modülü vardır:

- `XCO_CP_XLSX` – doküman/worksheet/coordinate factory
- `XCO_CP_XLSX_SELECTION` – `simple_from_to` selection pattern
- `XCO_CP_XLSX_READ_ACCESS` – `string_value`, `best_effort`, `identity` dönüşümleri
- `XCO_CP_XLSX_WRITE_ACCESS` – yeni XLSX üretimi

Bu proje XCO'yu doğrudan, ince bir adapter katmanında kullanır. CSV yolu ise tamamen
 ABAP ile yazılmıştır ve her sürümde çalışır.

**Sürüm notu**

| Yetenek | Minimum ortam |
|---|---|
| XLSX okuma | BTP ABAP Environment 2208+, S/4HANA 2023 / BASIS 758+ |
| XLSX yazma | Daha yeni sürümler (write access içeren XCO XLSX; ör. ABAP Platform 2025 FPS01+) |
| CSV okuma/yazma | Tüm ABAP Cloud sürümleri |

Kütüphane açılışta `ZCL_EXCEL_SHEET=>IS_XLSX_AVAILABLE( )` ile yeteneği kontrol eder.
XLSX yoksa `read( )` / `write( )` anlaşılır bir hata verir; CSV yolu çalışmaya devam eder.

## Katmanlar

| Nesne | Görev |
|---|---|
| `ZCL_EXCEL_SHEET` | Düşük seviye cephe: `READ`, `READ_INTO`, `READ_DYNAMIC`, `WRITE`, `READ_CSV`, `WRITE_CSV`, `GET_SHEET_NAMES` |
| `ZIF_EXCEL_XLSX` | Provider sözleşmesi (XCO'ya bağımlı olmayan tipler) |
| `ZCL_EXCEL_XLSX` | XCO_CP_XLSX kullanan gerçek XLSX adaptörü |
| `ZCL_EXCEL_IMPORT` | Format tespiti, başlık eşleme, tip dönüşümü, doğrulama raporu, şablon üretimi |
| `ZCX_EXCEL_SHEET` | Satır/kolon/alan bilgisi taşıyan istisna |
| `ZCL_EXCEL_ORDER_DEMO` | Toplu sipariş örneği (template + upload + validate) |

`ZCL_EXCEL_SHEET`, XLSX adaptörünü dinamik olarak yükler (`CREATE OBJECT ... TYPE
('ZCL_EXCEL_XLSX')`). Böylece cephe, XCO sınıflarının bulunmadığı sistemlerde de
aktive olur ve yerel `skybox` çalışma zamanında CSV testleri çalışır.

## Kurulum

`src/` klasörünü abapGit ile ilgili ABAP Cloud paketine bağlayın. `skybox.yaml`
dosyası yalnızca yerel geliştirme içindir; `ZCL_EXCEL_XLSX` adaptörü yerel runtime'da
XCO bulunmadığı için `exclude` listesindedir.

## Kullanım

### 1) Ham satırlar (string tablo)

```abap
DATA(rows) = zcl_excel_import=>rows(
  content  = lv_upload_content
  filename = lv_filename          " .xlsx veya .csv
  sheet    = 1 ).

LOOP AT rows INTO DATA(row).
  " row-cells[ 1 ] ...
ENDLOOP.
```

### 2) Tipli tabloya, başlığa göre doldurma (toplu sipariş)

```abap
TYPES: BEGIN OF ty_order,
         material      TYPE string,
         quantity      TYPE i,
         delivery_date TYPE d,
       END OF ty_order,
       tt_orders TYPE STANDARD TABLE OF ty_order WITH EMPTY KEY.

DATA(orders) = VALUE tt_orders( ).
DATA(report) TYPE zcl_excel_import=>ty_report.

CALL METHOD zcl_excel_import=>import
  EXPORTING
    content   = lv_upload_content
    filename  = lv_filename
    header    = abap_true
    aliases   = VALUE zcl_excel_import=>ty_aliases(
      ( label = `Malzeme`       field = `MATERIAL` )
      ( label = `Miktar`        field = `QUANTITY` )
      ( label = `Teslim Tarihi` field = `DELIVERY_DATE` ) )
    required  = VALUE string_table( ( `MATERIAL` ) ( `QUANTITY` ) )
    separator = `;`
  CHANGING
    data      = orders
  RECEIVING
    report    = report.
```

`report` içeriği:

- `ROWS_READ` – başlık dahil okunan satır sayısı
- `ROWS_IMPORTED` / `ROWS_REJECTED` – kabul/red edilen veri satırları
- `MESSAGES` – `ROW`, `COLUMN`, `FIELD`, `SEVERITY` (`E`/`W`/`I`), `TEXT`

Varsayılan eşleme, başlık ve alan adını büyük harfe çevirip boşluk/altçizgi/dash
ve Türkçe karakterleri normalize eder (`Teslim Tarihi` ↔ `DELIVERY_DATE` için
yine de alias verin). `HEADER = ABAP_FALSE` ise kolonlar konuma göre eşlenir.

Desteklenen dönüşümler: `STRING`/`CHAR`, `I`/`INT8`/`P`/`DECFLOAT`/`F`, `D`, `T`, `NUMC`.
Tarih için `YYYYMMDD`, `YYYY-MM-DD`, `DD.MM.YYYY` ve `MM/DD/YYYY` kabul edilir.
Sayılarda hem `1.234,56` hem `1,234.56` biçimi işlenir.

### 3) RAP custom action içinde

```abap
METHOD upload_orders.
  " lv_content: RAP attachment / OData V4 custom action / dosya akışından gelen xstring
  " orders: tipi sipariş tablosu
  " yukarıdaki CALL METHOD zcl_excel_import=>import ... çağrısını yapın

  LOOP AT report-messages INTO DATA(message).
    APPEND VALUE #( severity = message-severity
                    message  = message-text ) TO exported_messages.
  ENDLOOP.

  IF lines( orders ) > 0.
    " kendi create action'ınız / draft MODIFY çağrınız
  ENDIF.
ENDMETHOD.
```

Kütüphane dosyanın **nereden geldiğini bilmez**; sözleşmesi `xstring`'dir.
Bu sayede GUI_UPLOAD'a ihtiyaç kalmaz.

### 4) Şablon indirme

```abap
DATA(template_xstring) = zcl_excel_import=>template(
  headings   = VALUE string_table( ( `Malzeme` ) ( `Miktar` ) ( `Teslim Tarihi` ) )
  format     = zcl_excel_import=>format_xlsx
  sheet_name = `Siparisler` ).
```

Dönen `xstring` doğrudan RAP attachment, mail eki (`CL_BCS_MAIL_BINARYPART`) veya
HTTP response body olarak verilebilir.

## Yerel geliştirme

```powershell
.\skybox.exe run  -dir .
.\skybox.exe test -dir .
```

> `skybox.exe` 35 MB olduğu için `.gitignore` ile repo dışında tutulur.
> Yerel çalıştırma için dosyayı kendi makinenizde bulundurun.

`ZCL_SKYBOX_CONSOLE`, toplu sipariş örneğini çalıştırır. Yerel ortamda XCO
bulunmadığından örnek otomatik olarak CSV şablonuna geçer; gerçek cloud'da XLSX
kullanılır.

## Sınırlar

- `READ` / `READ_DYNAMIC` string modunda A..BL (64 kolon) okur. Daha geniş tablolar
  için `READ_INTO` ile kendi yapınızı verin.
- Sadece düz (flat) yapılar desteklenir; nested yapı/reference alan red edilir.
- XCO veri odaklıdır; formül, makro ve zengin formatting bilgilerini korumaz.
  Böyle bir ihtiyaç varsa klasik ABAP'ta `abap2xlsx` kullanılmalıdır.
- Dosya boyutu ve satır sayısı, RAP endpoint'inizin sınırlarına tabidir; çok büyük
  dosyalarda parça parça yükleme önerilir.

## GitHub'a yayınlama

Repo: **`abap-cloud-excel`** (public). Bu makinede `git` ve `gh` kurulu değildi;
kurulum ve giriş adımlarını kullanıcı yapar:

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e

# YENI PowerShell penceresi:
gh auth login
```

Ardından tek komutla repo oluşturulur ve push edilir:

```powershell
cd C:\Users\Teampro1\abap-cloud-xlsx
.\publish.ps1
```

Script mevcut repo'yu algılarsa `origin` URL'sini güncelleyip `main` dalına push eder;
yoksa `gh repo create ... --public --source=. --push` ile yeni repo açar.
