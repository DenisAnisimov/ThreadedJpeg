unit ThreadedJpeg;

// Based on NativeJpeg (C) Simdesign BV, all rights reserved.

// 1.1
// Reading of Haffman codes improved

// 1.0
// Initial release

{$DEFINE SUPPORT_GRAPHICS}
{ $DEFINE SUPPORT_GRAPHICS32}

interface

uses
  Windows, Classes
  {$IFDEF SUPPORT_GRAPHICS}, Graphics{$ENDIF}
  {$IFDEF SUPPORT_GRAPHICS32}, GR32{$ENDIF}
  ;

const
  JPEG_OK                            = 0;
  JPEG_UNEXPECTED_EOF                = 1;
  JPEG_UNEXPECTED_EOI                = 2;
  JPEG_INVALID_MARKER_FOUND          = 3;
  JPEG_UNSUPPORTED_COMRESSION_METHOD = 4;
  JPEG_UNSUPPORTED_COLOR_SPACE       = 5;
  JPEG_DATA_ERROR                    = 6;

type
  TsdJpegColorSpace = (
    jcAutoDetect,   // Auto-detect the colorspace from the file
    jcGray,         // 1-Channel grayscale
    jcGrayA,        // 1-Channel grayscale with Alpha channel
    jcRGB,          // (standard) RGB
    jcRGBA,         // (standard) RGB with Alpha channel
    jcYCbCr,        // Jpeg Y-Cb-Cr
    jcYCbCrA,       // Jpeg Y-Cb-Cr with Alpha channel
    jcCMYK,         // CMYK
    jcYCbCrK,       // CMYK represented in 4 channels as YCbCrK
    jcYCCK,         // YCCK
    jcPhotoYCC,     // Photo YCC
    jcPhotoYCCA,    // Photo YCCA
    jcITUCieLAB     // ITU G3FAX CieLAB (for use in colour faxes)
  );

type
  TsdSampleBlock = array[0..63] of Byte;
  TsdIntArray64 = array[0..63] of Integer;
  PsdIntArray64 = ^TsdIntArray64;

  TdecDQTTable = record
    Inited: Boolean;
    Values: array[0..63] of Word;
    ValuesEx: TsdIntArray64;
  end;
  PdecDQTTable = ^TdecDQTTable;

  TdecDHTValue = record
    Count: Integer;    // Count of codes in group
    MinValue: Integer; // Min Huffman code
    MaxValue: Integer; // Max Huffman code
    MinIndex: Integer; // Offset to first code
  end;
  PdecDHTValue = ^TdecDHTValue;

  TdecDHTFastValue = record
    Value: Cardinal;
    BitCount: Cardinal;
  end;

  TdecDHTTable = record
    HuffmanCodes: array[1..16] of TdecDHTValue;
    Values: array[0..255] of Byte;
    FastValues: array[0..255] of TdecDHTFastValue;
    MinHuffmanLen: Integer;
    Inited: Boolean;
    Filled: Boolean;
  end;
  PdecDHTTable = ^TdecDHTTable;

  TdecSOFComponent = record
    ID: Byte;
    VertSampling: Integer;
    HorzSampling: Integer;
    DQT_TableIndex: Byte;
    DQTTable: TdecDQTTable;
  end;
  PdecSOFComponent = ^TdecSOFComponent;

  TdecSOF = record
    Inited: Boolean;
    Type_: Integer;
    SamplePrecision: Integer;
    ImageWidth: Integer;
    ImageHeight: Integer;
    ComponentCount: Integer;
    Components: array[0..3] of TdecSOFComponent;
    MaxHorzSampling: Integer;
    MaxVertSampling: Integer;
    MCUWidth: Integer;
    MCUHeight: Integer;
  end;

  TdecSOSComponent = record
    ID: Byte;
    SOFIndex: Integer;
    HorzSampling: Integer;
    VertSampling: Integer;
    DUWidth: Integer;
    DUHeight: Integer;
    DUHorzCount: Integer;
    DUVertCount: Integer;
    DQT_TableIndex: Integer;
    DHT_DCTableIndex: Integer;
    DHT_ACTableIndex: Integer;
    PrevDC: Integer;
    KeepDC: Boolean;
    KeepDCValue: Integer;
    {$IFDEF DEBUG}
    DebugTable_: array[0..63] of Integer;
    {$ENDIF}
  end;
  PdecSOSComponent = ^TdecSOSComponent;

  TdecSOS = record
    Inited: Boolean;
    ComponentCount: Integer;
    Components: array[0..3] of TdecSOSComponent;
    SpectralStart: Integer;
    SpectralEnd: Integer;
    ApproxHigh: Integer;
    ApproxLow: Integer;

    MaxHorzSampling: Integer;
    MaxVertSampling: Integer;
    MCUWidth: Integer;
    MCUHeight: Integer;
    MCUHorzCount: Integer;
    MCUVertCount: Integer;
  end;
  PdecSOS = ^TdecSOS;

  TdecDataUnit = record
    Values: packed array[0..63] of SmallInt;
  end;
  PdecDataUnit = ^TdecDataUnit;

  TdecJpegMap = class(TObject)
  public
    constructor Create(AItemSize: Integer);
    destructor Destroy; override;
    procedure Clear;
    procedure SetSize(AWidth, AHeight: Integer);
    procedure ZeroData;
    procedure FillData(AValue: Byte);
  private
    FData: Pointer;
    FDataSize: Integer;
    FWidth: Integer;
    FHeight: Integer;
    FItemSize: Integer; //in bytes
    FLineSize: Integer; //in bytes
    procedure SetWidth(AWidth: Integer);
    procedure SetHeight(AHeight: Integer);
    function GetValue(AX, AY: Integer): Pointer; {$IFNDEF DEBUG}inline;{$ENDIF}
  public
    property Data: Pointer read FData;
    property Width: Integer read FWidth write SetWidth;
    property Height: Integer read FHeight write SetHeight;
    property LineSize: Integer read FLineSize;
    property Values[AX, AY: Integer]: Pointer read GetValue;
  end;

  TdecMCUs = class(TdecJpegMap)
  public
    constructor Create;
    procedure Update(const ASOF: TdecSOF; const ASOS: TdecSOS; AComponentIndex: Integer);
  private
    FMCUHorzCount: Integer;
    FMCUVertCount: Integer;
    FMCUWidth: Integer;
    FMCUHeight: Integer;
    FDUHorzCount: Integer;
    FDUVertCount: Integer;
    FDUCount: Integer;
    FDUWidth: Integer;
    FDUHeight: Integer;
    FPixelHorzRepeatCount: Integer;
    FPixelVertRepeatCount: Integer;
    procedure SetMCUVertCount(AMCUVertCount: Integer);
    function GetValue(AX, AY, AComponentIndex2: Integer): PdecDataUnit; {$IFNDEF DEBUG}inline;{$ENDIF}
    function GetRealValue(AX, AY: Integer): PdecDataUnit; {$IFNDEF DEBUG}inline;{$ENDIF}
  public
    property MCUHorzCount: Integer read FMCUHorzCount;
    property MCUVertCount: Integer read FMCUVertCount write SetMCUVertCount;
    property MCUWidth: Integer read FMCUWidth;
    property MCUHeight: Integer read FMCUHeight;
    property DUHorzCount: Integer read FDUHorzCount;
    property DUVertCount: Integer read FDUVertCount;
    property DUCount: Integer read FDUCount;
    property DUWidth: Integer read FDUWidth;
    property DUHeight: Integer read FDUHeight;
    property PixelHorzRepeatCount: Integer read FPixelHorzRepeatCount;
    property PixelVertRepeatCount: Integer read FPixelVertRepeatCount;
    property Values[AX, AY, AComponentIndex2: Integer]: PdecDataUnit read GetValue;
    property RealValues[AX, AY: Integer]: PdecDataUnit read GetRealValue;
  end;

  TdecComponentValue = SmallInt;
  PdecComponentValue = ^TdecComponentValue;

  TdecComponentData = class(TdecJpegMap)
  public
    constructor Create(AWidth, AHeight: Integer);
  private
    function GetValue(AX, AY: Integer): TdecComponentValue; inline;
    procedure SetValue(AX, AY: Integer; AValue: TdecComponentValue); inline;
  public
    property Values[AX, AY: Integer]: TdecComponentValue read GetValue write SetValue; default;
  end;

  TdecComponentDatas = array[0..3] of TdecComponentData;

  TdecJpegThreadSignal = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;
    procedure WaitFor;
    function FreeThreadCount: Integer;
  private
    FLock: TRTLCriticalSection;
    FDoneEvent: THandle;
    FValue: Integer;
    FMaxThreadCount: Integer;
    procedure IncSignal;
    procedure DecSignal;
  end;

  TdecJpegImage = class(TObject)
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function LoadFromStream(AStream: TStream; out ABitmap: HBITMAP): Cardinal; overload;
    {$IFDEF SUPPORT_GRAPHICS}
    function LoadFromStream(AStream: TStream; out ABitmap: TBitmap): Cardinal; overload;
    {$ENDIF}
    {$IFDEF SUPPORT_GRAPHICS32}
    function LoadFromStream(AStream: TStream; out ABitmap32: TBitmap32): Cardinal; overload;
    {$ENDIF}
  private
    FStream: TStream;
    FBuffer: PByte;
    FBufferSize: Cardinal;
    FBufferPos: PByte;
    FBufferAvailableSize: Cardinal;
    FSegment: PByte;

    FColorSpace: TsdJpegColorSpace;
    FJFIFFound: Boolean;
    FAdobeFound: Boolean;
    FAdobeTransform: Byte;
    FG3FAXFound: Boolean;
    FICC_PROFILEFound: Boolean;

    FEnabledMarkers: set of Byte;
    FDQTTables: array[0..3] of TdecDQTTable;
    FDC_DHTTables: array[0..3] of TdecDHTTable;
    FAC_DHTTables: array[0..3] of TdecDHTTable;
    FSOF: TdecSOF;
    FSOS: TdecSOS;
    FUnknownHeight: Boolean;
    FScanCount: Integer;
    FComponentIDs: AnsiString;
    FRestartInterval: Integer;

    FDecodeError: Boolean;
    FRestartCounter: Integer;
    FNextRSTIndex: Integer;
    FCurrentMCUIndex: Integer;
    FMCU: array[0..3] of TdecMCUs;
    FComponents_: TdecComponentDatas;

    FSignal: TdecJpegThreadSignal;
    FBitmapBPS: Integer; // Bit per sample
    FBitmapBPL: Integer; // Bytes per line
    {$IFDEF SUPPORT_GRAPHICS32}
    FBitmap32Mode: Boolean;
    FBitmap32: TBitmap32;
    {$ENDIF}
    FBitmap: HBITMAP;
    FBitmapBits: PByte;
    FNextDecodeMCULine: Integer;

    function DoLoadFromStream(AStream: TStream): Cardinal;
    {$IFDEF DEBUG}
    procedure Error(const AMessage: string; AOffset: Integer);
    {$ENDIF}
    function Read(ABuffer: PByte; ASize: Cardinal): Cardinal;
    function ReadByte(out AByte: Byte): Cardinal; overload; inline;
    function ReadByte(out AByte: Integer): Cardinal; overload; inline;
    function PreviewByte(out AByte: Integer): Cardinal; inline;
    function ReadMarker(out AMarker: Byte): Cardinal;
    function ReadSize(AMarker: Byte; out ASize: Word): Cardinal;
    function ReadSegment(ASize: Word): Word;
    procedure ReadAPP(AMarker: Byte; ASize: Word);
    function ReadDQT(ASize: Word): Cardinal;
    function InitDHT(ATable: PdecDHTTable): Cardinal;
    function ReadDHT(ASize: Word): Cardinal;
    function ReadDRI(ASize: Word): Cardinal;
    function ReadSOF(AMarker: Byte; ASize: Word): Cardinal;
    function ReadSOS(ASize: Word): Cardinal;
    function DetectColorSpace: TsdJpegColorSpace;
  private
    FBits: Integer;
    FAvailableBitCount: Integer;
    FRealAvailableBitCount: Integer;
    procedure InitBitReaded; inline;
    procedure AfterRestart;
    function FillBits: Cardinal;
    function ReadBit(out ABit: Integer): Cardinal; inline;
    function ReadBits(ACount: Integer; out ABits: Integer): Cardinal;
    function ReadHuffman(ATable: PdecDHTTable; out AValue: Integer): Cardinal;
  private
    function GetValues(AComponentIndex, AComponentIndex2, AMCUHorzIndex, AMCUVertIndex: Integer): PdecDataUnit; //inline;

    function ReadBaselineHuffmanDataUnit(AComponentIndex: Integer; ADCAC: PdecDataUnit): Cardinal;
    function ReadProgressiveHuffmanDCBandFirst(AComponentIndex: Integer; ADCAC: PdecDataUnit): Cardinal;
    function ReadProgressiveHuffmanDCBandNext(ADCAC: PdecDataUnit): Cardinal;
    function ReadProgressiveHuffmanACBandFirst(var EOBRun: integer; AComponentIndex: Integer; ADCAC: PdecDataUnit): Cardinal;
    function ReadProgressiveHuffmanACBandNext(var EOBRun: integer; AComponentIndex: Integer; ADCAC: PdecDataUnit): Cardinal;

    procedure RSTFound(RST: Byte; var MCUHorzIndex, MCUVertIndex: Integer);
    procedure FindNextRST(var MCUHorzIndex, MCUVertIndex: Integer);
    function DecodeScan: Cardinal;
    procedure UpdateComponentDatas(var AComponentDatas: TdecComponentDatas);
    procedure PrepareCreateBitmap;
    procedure PostCreateBitmapEx;
    procedure PostCreateBitmap;
  protected
    procedure JobIDCT(const AComponents: TdecComponentDatas; AMCULine: Integer);
    procedure JobGray8(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobGray24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobGray32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobGrayA24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobGrayA32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobRGB24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobRGB32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobRGBA24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobRGBA32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobYCbCr24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobYCbCr32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobYCbCrA24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobYCbCrA32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobCMYKAdobe24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobCMYKAdobe32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobYCCK24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobYCCK32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
    procedure JobDecode(const AComponents: TdecComponentDatas; AMCULine, AMCULineCount: Integer);
  end;

  TdecJpegThreadJobRecord = record
    Jpeg: TdecJpegImage;
    FirstMCULine: Integer;
    MCULineCount: Integer;
  end;

  TdecJpegThread = class(TThread)
  public
    constructor Create;
    destructor Destroy; override;
    procedure Terminate;
  protected
    procedure Execute; override;
  private
    FWakeUp: THandle;
    FJob: TdecJpegThreadJobRecord;
    FComponents: TdecComponentDatas;
    procedure SetJob(AJob: TdecJpegThreadJobRecord);
  end;

implementation

uses
  SysUtils;

{$IFDEF CPU386}
function Swap16(AValue: Word): Word;
asm
  xchg al, ah;
end;
{$ELSE}
function Swap16(AValue: Word): Word; inline;
begin
  Result := ((AValue shr 8) and $FF) or ((AValue shl 8) and $FF00);
end;
{$ENDIF}

const
  // Jpeg markers defined in Table B.1
  mkSOF0  = $c0; // Baseline DCT + Huffman encoding
  mkSOF1  = $c1; // Extended Sequential DCT + Huffman encoding
  mkSOF2  = $c2; // Progressive DCT + Huffman encoding
  mkSOF3  = $c3; // Lossless (sequential) + Huffman encoding

  mkSOF5  = $c5; // Differential Sequential DCT + Huffman encoding
  mkSOF6  = $c6; // Differential Progressive DCT + Huffman encoding
  mkSOF7  = $c7; // Differential Lossless (sequential) + Huffman encoding

  mkJPG   = $c8; // Reserved for Jpeg extensions
  mkSOF9  = $c9; // Extended Sequential DCT + Arithmetic encoding
  mkSOF10 = $ca; // Progressive DCT + Arithmetic encoding
  mkSOF11 = $cb; // Lossless (sequential) + Arithmetic encoding

  mkSOF13 = $cd; // Differential Sequential DCT + Arithmetic encoding
  mkSOF14 = $ce; // Differential Progressive DCT + Arithmetic encoding
  mkSOF15 = $cf; // Differential Lossless (sequential) + Arithmetic encoding

  mkDHT   = $c4; // Define Huffman Table

  mkDAC   = $cc; // Define Arithmetic Coding

  mkRST0  = $d0; // Restart markers
  mkRST1  = $d1;
  mkRST2  = $d2;
  mkRST3  = $d3;
  mkRST4  = $d4;
  mkRST5  = $d5;
  mkRST6  = $d6;
  mkRST7  = $d7;

  mkSOI   = $d8; // Start of Image
  mkEOI   = $d9; // End of Image
  mkSOS   = $da; // Start of Scan
  mkDQT   = $db; // Define Quantization Table
  mkDNL   = $dc; // Define Number of Lines
  mkDRI   = $dd; // Define Restart Interval
  mkDHP   = $de; // Define Hierarchical Progression
  mkEXP   = $df; // Expand reference components

  mkAPP0  = $e0; // APPn markers - APP0 = JFIF
  mkAPP1  = $e1; //                APP1 = EXIF or XMP
  mkAPP2  = $e2; //                ICC colour profile
  mkAPP3  = $e3;
  mkAPP4  = $e4;
  mkAPP5  = $e5;
  mkAPP6  = $e6;
  mkAPP7  = $e7;
  mkAPP8  = $e8;
  mkAPP9  = $e9;
  mkAPP10 = $ea;
  mkAPP11 = $eb;
  mkAPP12 = $ec;
  mkAPP13 = $ed; //                APP13 = IPTC or Adobe IRB
  mkAPP14 = $ee; //                APP14 = Adobe
  mkAPP15 = $ef;

  mkJPG0  = $f0; // JPGn markers - reserved for JPEG extensions
  mkJPG13 = $fd;
  mkCOM   = $fe; // Comment

  mkTEM   = $01; // Reserved for temporary use

const
  FColorConvScale = 1 shl 10;

var
  // YCbCr to RGB
  F__toR: integer;
  F__toG: integer;
  F__toB: integer;
  FY_toRT: array[0..255] of integer;
  FCrtoRT: array[0..255] of integer;
  FCbtoGT: array[0..255] of integer;
  FCrtoGT: array[0..255] of integer;
  FCbtoBT: array[0..255] of integer;

  // RGB to YCbCr
  F__toCb: integer;
  F__toCr: integer;
  FRtoY_: array[0..255] of integer;
  FGtoY_: array[0..255] of integer;
  FBtoY_: array[0..255] of integer;
  FRtoCb: array[0..255] of integer;
  FGtoCb: array[0..255] of integer;
  FBtoCb: array[0..255] of integer;
  FRtoCr: array[0..255] of integer;
  FGtoCr: array[0..255] of integer;
  FBtoCr: array[0..255] of integer;

procedure InitYCbCrTables;
{ YCbCr to RGB conversion: These constants come from JFIF spec

  R = Y                      + 1.402 (Cr-128)
  G = Y - 0.34414 (Cb-128) - 0.71414 (Cr-128)
  B = Y + 1.772 (Cb-128)

  or

  R = Y                + 1.402 Cr - 179.456
  G = Y - 0.34414 Cb - 0.71414 Cr + 135.53664
  B = Y +   1.772 Cb              - 226.816
}
var
  i: integer;
begin
  F__toR := Round(-179.456   * FColorConvScale);
  F__toG := Round( 135.53664 * FColorConvScale);
  F__toB := Round(-226.816   * FColorConvScale);
  for i := 0 to 255 do
    begin
      FY_toRT[i] := Round(  1       * FColorConvScale * i);
      FCrtoRT[i] := Round(  1.402   * FColorConvScale * i);
      FCbtoGT[i] := Round( -0.34414 * FColorConvScale * i);
      FCrtoGT[i] := Round( -0.71414 * FColorConvScale * i);
      FCbtoBT[i] := Round(  1.772   * FColorConvScale * i);
    end;
end;

procedure InitRGBToYCbCrTables;
{  RGB to YCbCr conversion: These constants come from JFIF spec

  Y =    0.299  R + 0.587  G + 0.114  B
  Cb = - 0.1687 R - 0.3313 G + 0.5    B + 128
  Cr =   0.5    R - 0.4187 G - 0.0813 B + 128
}
var
  i: integer;
begin
  F__toCb := Round(128 * FColorConvScale);
  F__toCr := Round(128 * FColorConvScale);
  for i := 0 to 255 do
    begin
      FRtoY_[i] := Round( 0.299  * FColorConvScale * i);
      FGtoY_[i] := Round( 0.587  * FColorConvScale * i);
      FBtoY_[i] := Round( 0.114  * FColorConvScale * i);
      FRtoCb[i] := Round(-0.1687 * FColorConvScale * i);
      FGtoCb[i] := Round(-0.3313 * FColorConvScale * i);
      FBtoCb[i] := Round( 0.5    * FColorConvScale * i);
      FRtoCr[i] := Round( 0.5    * FColorConvScale * i);
      FGtoCr[i] := Round(-0.4187 * FColorConvScale * i);
      FBtoCr[i] := Round(-0.0813 * FColorConvScale * i);
    end;
end;

function MaxThreadCount: Integer;
var
  SysInfo: TSystemInfo;
begin
  GetNativeSystemInfo(SysInfo);
  Result := SysInfo.dwNumberOfProcessors;
end;

var
  Threads: TList;
  FreeThreads: TList;
  ThreadLock: TRTLCriticalSection;

procedure AddJob(AJob: TdecJpegThreadJobRecord);
var
  Thread: TdecJpegThread;
begin
  EnterCriticalSection(ThreadLock);
  try
    if FreeThreads.Count > 0 then
      begin
        Thread := TdecJpegThread(FreeThreads[FreeThreads.Count - 1]);
        FreeThreads.Delete(FreeThreads.Count - 1);
      end
    else
      begin
        Thread := TdecJpegThread.Create;
        try
          Threads.Add(Thread);
        except
          Thread.Terminate;
          Thread.WaitFor;
          Thread.Free;
          raise;
        end;
      end;

    Thread.SetJob(AJob);
  finally
    LeaveCriticalSection(ThreadLock);
  end;

  AJob.Jpeg.FSignal.IncSignal;
end;

type
  EJpegDecoderException = class(Exception);

{$IFDEF DEBUG}
function MarkerToString(AMarker: Byte): string;
begin
  case AMarker of
    mkSOF0:  Result := 'SOF0';
    mkSOF1:  Result := 'SOF1';
    mkSOF2:  Result := 'SOF2';
    mkSOF3:  Result := 'SOF3';
    mkSOF5:  Result := 'SOF5';
    mkSOF6:  Result := 'SOF6';
    mkSOF7:  Result := 'SOF7';
    mkJPG:   Result := 'JPG';
    mkSOF9:  Result := 'SOF9';
    mkSOF10: Result := 'SOF10';
    mkSOF11: Result := 'SOF11';
    mkSOF13: Result := 'SOF13';
    mkSOF14: Result := 'SOF14';
    mkSOF15: Result := 'SOF5';
    mkDHT:   Result := 'DHT';
    mkDAC:   Result := 'DAC';
    mkRST0:  Result := 'RST0';
    mkRST1:  Result := 'RST1';
    mkRST2:  Result := 'RST2';
    mkRST3:  Result := 'RST3';
    mkRST4:  Result := 'RST4';
    mkRST5:  Result := 'RST5';
    mkRST6:  Result := 'RST6';
    mkRST7:  Result := 'RST7';
    mkSOI:   Result := 'SOI';
    mkEOI:   Result := 'EOI';
    mkSOS:   Result := 'SOS';
    mkDQT:   Result := 'DQT';
    mkDNL:   Result := 'DNL';
    mkDRI:   Result := 'DRI';
    mkDHP:   Result := 'DHP';
    mkEXP:   Result := 'EXP';
    mkAPP0:  Result := 'APP0';
    mkAPP1:  Result := 'APP1';
    mkAPP2:  Result := 'APP2';
    mkAPP3:  Result := 'APP3';
    mkAPP4:  Result := 'APP4';
    mkAPP5:  Result := 'APP5';
    mkAPP6:  Result := 'APP6';
    mkAPP7:  Result := 'APP7';
    mkAPP8:  Result := 'APP8';
    mkAPP9:  Result := 'APP9';
    mkAPP10: Result := 'APP10';
    mkAPP11: Result := 'APP11';
    mkAPP12: Result := 'APP12';
    mkAPP13: Result := 'APP13';
    mkAPP14: Result := 'APP14';
    mkAPP15: Result := 'APP15';
    mkJPG0:  Result := 'JPG0';
    mkJPG13: Result := 'JPG13';
    mkCOM:   Result := 'COM';
    mkTEM:   Result := 'TEM';
  else
    Result := IntToHex(AMarker, 2);
  end;
end;
{$ENDIF}

//**************************************************************************************************
// TdecJpegMap
//**************************************************************************************************

constructor TdecJpegMap.Create(AItemSize: Integer);
begin
  inherited Create;
  FItemSize := AItemSize;
end;

destructor TdecJpegMap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TdecJpegMap.Clear;
begin
  FWidth := 0;
  FHeight := 0;
  if Assigned(FData) then
    begin
      FreeMem(FData);
      FData := nil;
    end;
  FDataSize := 0;
  FLineSize := 0;
end;

procedure TdecJpegMap.SetSize(AWidth, AHeight: Integer);
var
  NewDataSize: Integer;
  NewLineSize: Integer;
  ZeroSize: Integer;
  Y: Integer;
  Source, Dest, ZeroDest: PByte;
begin
  if (FWidth = AWidth) and (FHeight = AHeight) then Exit;

  NewLineSize := AWidth * FItemSize;
  NewDataSize := NewLineSize * AHeight;

  if FHeight = 0 then
    FWidth := AWidth
  else
    if AWidth = 0 then
      begin
        if Assigned(FData) then
          begin
            FreeMem(FData);
            FData := nil;
          end;
      end
    else
      if AWidth > FWidth then
        begin
          FData := ReallocMemory(FData, NewDataSize);

          if FWidth = 0 then
            ZeroMemory(FData, NewDataSize)
          else
            begin
              ZeroSize := NewLineSize - FLineSize;
              Source := PByte(FData);
              Inc(Source, FLineSize * (FHeight - 1));
              Dest := PByte(FData);
              Inc(Dest, NewLineSize * (FHeight - 1));
              ZeroDest := Dest;
              Inc(ZeroDest, FLineSize);
              for Y := Height - 1 downto 0 do
                begin
                  CopyMemory(Dest, Source, FLineSize);
                  ZeroMemory(ZeroDest, ZeroSize);
                  Dec(Source, FLineSize);
                  Dec(Dest, NewLineSize);
                  Dec(ZeroDest, NewLineSize);
                end;
            end;
        end
      else
        if AWidth < FWidth then
          begin
            Source := PByte(FData);
            Inc(Source, FLineSize);
            Dest := PByte(FData);
            Inc(Dest, NewLineSize);
            for Y := Height - 2 downto 0 do
              begin
                CopyMemory(Dest, Source, FLineSize);
                Inc(Source, FLineSize);
                Inc(Dest, NewLineSize);
              end;

            FData := ReallocMemory(FData, NewDataSize);
          end;

  FDataSize := NewDataSize;
  FLineSize := NewLineSize;
  FWidth := AWidth;
end;

procedure TdecJpegMap.ZeroData;
begin
  if Assigned(FData) then
    ZeroMemory(FData, FDataSize);
end;

procedure TdecJpegMap.FillData(AValue: Byte);
begin
  if Assigned(FData) then
    FillChar(FData^, FDataSize, AValue);
end;

procedure TdecJpegMap.SetWidth(AWidth: Integer);
var
  NewDataSize: Integer;
  NewLineSize: Integer;
  ZeroSize: Integer;
  Y: Integer;
  Source, Dest, ZeroDest: PByte;
begin
  if FWidth = AWidth then Exit;

  NewLineSize := AWidth * FItemSize;
  NewDataSize := NewLineSize * FHeight;

  if FHeight = 0 then
    FWidth := AWidth
  else
    if AWidth = 0 then
      begin
        if Assigned(FData) then
          begin
            FreeMem(FData);
            FData := nil;
          end;
      end
    else
      if AWidth > FWidth then
        begin
          FData := ReallocMemory(FData, NewDataSize);

          if FWidth = 0 then
            ZeroMemory(FData, NewDataSize)
          else
            begin
              ZeroSize := NewLineSize - FLineSize;
              Source := PByte(FData);
              Inc(Source, FLineSize * (FHeight - 1));
              Dest := PByte(FData);
              Inc(Dest, NewLineSize * (FHeight - 1));
              ZeroDest := Dest;
              Inc(ZeroDest, FLineSize);
              for Y := Height - 1 downto 0 do
                begin
                  CopyMemory(Dest, Source, FLineSize);
                  ZeroMemory(ZeroDest, ZeroSize);
                  Dec(Source, FLineSize);
                  Dec(Dest, NewLineSize);
                  Dec(ZeroDest, NewLineSize);
                end;
            end;
        end
      else
        if AWidth < FWidth then
          begin
            Source := PByte(FData);
            Inc(Source, FLineSize);
            Dest := PByte(FData);
            Inc(Dest, NewLineSize);
            for Y := Height - 2 downto 0 do
              begin
                CopyMemory(Dest, Source, FLineSize);
                Inc(Source, FLineSize);
                Inc(Dest, NewLineSize);
              end;

            FData := ReallocMemory(FData, NewDataSize);
          end;

  FDataSize := NewDataSize;
  FLineSize := NewLineSize;
  FWidth := AWidth;
end;

procedure TdecJpegMap.SetHeight(AHeight: Integer);
var
  NewDataSize: Integer;
  ZeroDest: PByte;
begin
  if FHeight = AHeight then Exit;

  NewDataSize := FLineSize * AHeight;

  if FWidth = 0 then
    FHeight := AHeight
  else
    if AHeight = 0 then
      begin
        if Assigned(FData) then
          begin
            FreeMem(FData);
            FData := nil;
          end;
      end
    else
      begin
        FData := ReallocMemory(FData, NewDataSize);
        if AHeight > FHeight then
          begin
            ZeroDest := PByte(FData);
            Inc(ZeroDest, FLineSize * FHeight);
            ZeroMemory(ZeroDest, FLineSize * (AHeight - FHeight));
          end
      end;

  FDataSize := NewDataSize;
  FHeight := AHeight;
end;

function TdecJpegMap.GetValue(AX, AY: Integer): Pointer;
begin
  {$IFDEF DEBUG}
  if (AX >= Width) or (AY >= Height) then
    begin
      MessageBox(0, 'TdecJpegMap.GetValue error', nil, MB_ICONERROR);
      Result := nil;
      Exit;
    end;
  {$ENDIF}
  Result := FData;
  Inc(PByte(Result), FLineSize * AY);
  Inc(PByte(Result), FItemSize * AX);
end;

//**************************************************************************************************
// TdecMCUs
//**************************************************************************************************

constructor TdecMCUs.Create;
begin
  inherited Create(SizeOf(TdecDataUnit));
end;

procedure TdecMCUs.Update(const ASOF: TdecSOF; const ASOS: TdecSOS; AComponentIndex: Integer);
var
  SOSComponent: PdecSOSComponent;
begin
  FMCUHorzCount := ASOS.MCUHorzCount;
  FMCUVertCount := ASOS.MCUVertCount;
  FMCUWidth := ASOS.MCUWidth;
  FMCUHeight := ASOS.MCUHeight;
  SOSComponent := @ASOS.Components[AComponentIndex];
  FDUHorzCount := SOSComponent.DUHorzCount;
  FDUVertCount := SOSComponent.DUVertCount;
  FDUCount := FDUHorzCount * FDUVertCount;
  FDUWidth := SOSComponent.DUWidth;
  FDUHeight := SOSComponent.DUHeight;
  FPixelHorzRepeatCount := ASOF.MaxHorzSampling div SOSComponent.HorzSampling;
  FPixelVertRepeatCount := ASOF.MaxVertSampling div SOSComponent.VertSampling;
  Width := ASOS.MCUHorzCount * DUHorzCount;
  Height := ASOS.MCUVertCount * DUVertCount;
end;

procedure TdecMCUs.SetMCUVertCount(AMCUVertCount: Integer);
begin
  FMCUVertCount := AMCUVertCount;
  Height := MCUVertCount * DUVertCount;
end;

function TdecMCUs.GetValue(AX, AY, AComponentIndex2: Integer): PdecDataUnit;
begin
  AX := AX * DUHorzCount + AComponentIndex2 mod DUHorzCount;
  AY := AY * DUVertCount + AComponentIndex2 div DUHorzCount;
  Result := PdecDataUnit(inherited Values[AX, AY]);
end;

function TdecMCUs.GetRealValue(AX, AY: Integer): PdecDataUnit;
begin
  Result := PdecDataUnit(inherited Values[AX, AY]);
end;

//**************************************************************************************************
// TdecJpegImage
//**************************************************************************************************

function IsAPPMarker(AMarker: Byte): Boolean; inline;
begin
  Result := ((AMarker >= mkAPP0) and (AMarker <= mkAPP15)) or (AMarker = mkCOM);
end;

const
  BufferSize = 1024 * 1024;

constructor TdecJpegImage.Create;
begin
  inherited Create;
  GetMem(FBuffer, BufferSize);
  FBufferSize := BufferSize;
end;

destructor TdecJpegImage.Destroy;
begin
  Clear;
  if Assigned(FBuffer) then
    FreeMem(FBuffer);
  if Assigned(FSegment) then
    FreeMem(FSegment);
  inherited Destroy;
end;

procedure TdecJpegImage.Clear;
var
  Index: Integer;
begin
  FStream := nil;
  FBufferAvailableSize := 0;

  FColorSpace := jcAutoDetect;
  FJFIFFound := False;
  FAdobeFound := False;
  FAdobeTransform := 0;
  FG3FAXFound := False;
  FICC_PROFILEFound := False;

  ZeroMemory(@FDQTTables, SizeOf(FDQTTables));
  ZeroMemory(@FDC_DHTTables, SizeOf(FDC_DHTTables));
  ZeroMemory(@FAC_DHTTables, SizeOf(FAC_DHTTables));
  ZeroMemory(@FSOF, SizeOf(FSOF));
  ZeroMemory(@FSOS, SizeOf(FSOS));
  FUnknownHeight := False;
  FScanCount := 0;
  FComponentIDs := '';
  FRestartInterval := 0;

  FDecodeError := False;
  for Index := 0 to 3 do
    begin
      FreeAndNil(FMCU[Index]);
      FreeAndNil(FComponents_[Index]);
    end;

  FBitmapBPS := 0;
  {$IFDEF SUPPORT_GRAPHICS32}
  FreeAndNil(FBitmap32);
  {$ENDIF}
  if FBitmap <> 0 then
    begin
      DeleteObject(FBitmap);
      FBitmap := 0;
    end;
end;

function TdecJpegImage.LoadFromStream(AStream: TStream; out ABitmap: HBITMAP): Cardinal;
begin
  ABitmap := 0;
  Result := JPEG_DATA_ERROR;
  try
    try
      {$IFDEF SUPPORT_GRAPHICS32}
      FBitmap32Mode := False;
      {$ENDIF}
      Result := DoLoadFromStream(AStream);
    except
      if Assigned(FSignal) then
        begin
          FSignal.WaitFor;
          FreeAndNil(FSignal);
        end;
      raise;
    end;

    if Assigned(FSignal) then
      begin
        try
          if FNextDecodeMCULine * FSOF.MCUHeight < FSOF.ImageHeight then
            PostCreateBitmapEx;
        except
          FSignal.WaitFor;
          FreeAndNil(FSignal);
          raise;
        end;

        FSignal.WaitFor;
        FreeAndNil(FSignal);

        ABitmap := FBitmap;
        FBitmap := 0;
      end
    else
      if (FBitmap = 0) and FSOS.Inited then
        begin
          PostCreateBitmap;
          ABitmap := FBitmap;
          FBitmap := 0;
        end;
  finally
    Clear;
  end;
end;

{$IFDEF SUPPORT_GRAPHICS}
function TdecJpegImage.LoadFromStream(AStream: TStream; out ABitmap: TBitmap): Cardinal;
begin
  ABitmap := nil;
  Result := JPEG_DATA_ERROR;
  try
    try
      {$IFDEF SUPPORT_GRAPHICS32}
      FBitmap32Mode := False;
      {$ENDIF}
      Result := DoLoadFromStream(AStream);
    except
      if Assigned(FSignal) then
        begin
          FSignal.WaitFor;
          FreeAndNil(FSignal);
        end;
      raise;
    end;

    if Assigned(FSignal) then
      begin
        try
          if FNextDecodeMCULine * FSOF.MCUHeight < FSOF.ImageHeight then
            PostCreateBitmapEx;
        except
          FSignal.WaitFor;
          FreeAndNil(FSignal);
          raise;
        end;

        FSignal.WaitFor;
        FreeAndNil(FSignal);

        ABitmap := TBitmap.Create;
        try
          ABitmap.Handle := FBitmap;
          FBitmap := 0;
        except
          ABitmap.Free;
          raise;
        end;
      end
    else
      if (FBitmap = 0) and FSOS.Inited then
        begin
          PostCreateBitmap;

          ABitmap := TBitmap.Create;
          try
            ABitmap.Handle := FBitmap;
            FBitmap := 0;
          except
            ABitmap.Free;
            raise;
          end;
        end;
  finally
    Clear;
  end;
end;
{$ENDIF}

{$IFDEF SUPPORT_GRAPHICS32}
function TdecJpegImage.LoadFromStream(AStream: TStream; out ABitmap32: TBitmap32): Cardinal;
begin
  ABitmap32 := nil;
  Result := JPEG_DATA_ERROR;
  try
    try
      FBitmap32Mode := True;
      Result := DoLoadFromStream(AStream);
    except
      if Assigned(FSignal) then
        begin
          FSignal.WaitFor;
          FreeAndNil(FSignal);
        end;
      raise;
    end;

    if Assigned(FSignal) then
      begin
        try
          if FNextDecodeMCULine * FMCUHeight < FSOF.ImageHeight then
            PostCreateBitmapEx;
        except
          FSignal.WaitFor;
          FreeAndNil(FSignal);
          raise;
        end;

        FSignal.WaitFor;
        FreeAndNil(FSignal);

        ABitmap32 := FBitmap32;
        FBitmap32 := nil;
      end
    else
      if not Assigned(FBitmap32) and FSOS.Inited then
        begin
          PostCreateBitmap;

          ABitmap32 := FBitmap32;
          FBitmap32 := nil;
        end;
  finally
    Clear;
  end;
end;
{$ENDIF}

function TdecJpegImage.DoLoadFromStream(AStream: TStream): Cardinal;
var
  Marker: Byte;
  Size: Word;
  Read: Word;
begin
  Clear;
  FStream := AStream;
  FBufferAvailableSize := 0;
  FColorSpace := jcAutoDetect;

  Result := ReadMarker(Marker);
  if Result <> JPEG_OK then Exit;
  if Marker <> mkSOI then
    begin
      Result := JPEG_INVALID_MARKER_FOUND;
      {$IFDEF DEBUG}
      Error('SOI expected but ' + MarkerToString(Marker) + ' found.', 2);
      {$ENDIF}
      Exit;
    end;

  FEnabledMarkers := [mkAPP0..mkAPP15, mkCOM, mkDQT, mkDHT, mkDRI, mkSOF0..mkSOF3, mkSOF5..mkSOF7,
    mkSOF9..mkSOF11, mkSOF13..mkSOF15, mkSOS];

  while True do
    begin
      Result := ReadMarker(Marker);
      if Result <> JPEG_OK then Break;

      if not (Marker in FEnabledMarkers) then
        begin
          Result := JPEG_INVALID_MARKER_FOUND;
          {$IFDEF DEBUG}
          Error('Unexpected marker ' + MarkerToString(Marker) + ' found.', 2);
          {$ENDIF}
          Break;
        end;

      case Marker of
        mkEOI:
          begin
            if FDecodeError then Result := JPEG_DATA_ERROR
                            else Result := JPEG_OK;
            Break;
          end;
        mkRST0..mkRST7:;
      else
        begin
          FEnabledMarkers := FEnabledMarkers - [mkRST0..mkRST7];

          Result := ReadSize(Marker, Size);
          if Result <> JPEG_OK then Break;
          Read := ReadSegment(Size);
          if Read <> Size then
            begin
              Result := JPEG_UNEXPECTED_EOF;
              {$IFDEF DEBUG}
              Error('Unexpected EOF.', 2);
              {$ENDIF}
              Break;
            end;

          if IsAPPMarker(Marker) then
            ReadAPP(Marker, Size)
          else
            begin
              case Marker of
                mkDQT:
                  begin
                    Result := ReadDQT(Size);
                    if Result <> JPEG_OK then Break;
                  end;
                mkDHT:
                  begin
                    Result := ReadDHT(Size);
                    if Result <> JPEG_OK then Break;
                  end;
                mkDRI:
                  begin
                    Result := ReadDRI(Size);
                    if Result <> JPEG_OK then Break;
                  end;
                mkSOF0..mkSOF3, mkSOF5..mkSOF7, mkSOF9..mkSOF11, mkSOF13..mkSOF15:
                  begin
                    Result := ReadSOF(Marker, Size);
                    if Result <> JPEG_OK then Break;
                  end;
                mkSOS:
                  begin
                    Result := ReadSOS(Size);
                    if Result <> JPEG_OK then Break;
                  end;
              else
                Result := JPEG_INVALID_MARKER_FOUND;
                {$IFDEF DEBUG}
                Error('Unexpected marker ' + MarkerToString(Marker) + ' found.', 4 + Size);
                {$ENDIF}
                Break;
              end;
            end;

          case Marker of
            mkSOF0..mkSOF3, mkSOF5..mkSOF7, mkSOF9..mkSOF11, mkSOF13..mkSOF15:
              FEnabledMarkers := FEnabledMarkers - [mkSOF0..mkSOF3, mkSOF5..mkSOF7, mkSOF9..mkSOF11, mkSOF13..mkSOF15];
            mkSOS:
              begin
                if not FSOF.Inited then
                  begin
                    Result := JPEG_INVALID_MARKER_FOUND;
                    {$IFDEF DEBUG}
                    Error('SOS found but SOF was not found yet.', 2);
                    {$ENDIF}
                    Exit;
                  end;

                case FSOF.Type_ of
                  mkSOF0,
                  mkSOF1:
                    if (FSOS.ComponentCount = FSOF.ComponentCount) and not FUnknownHeight and
                      {$IFDEF SUPPORT_GRAPHICS32}not Assigned(FBitmap32) and{$ENDIF} (FBitmap = 0) then
                      begin
                        PrepareCreateBitmap;
                        FSignal := TdecJpegThreadSignal.Create;
                        FNextDecodeMCULine := 0;
                      end;
                end;

                case FSOF.Type_ of
                  mkSOF0,
                  mkSOF1,
                  mkSOF2:
                    begin
                      if FColorSpace = jcAutoDetect then
                        FColorSpace := DetectColorSpace;
                      FEnabledMarkers := [mkDQT, mkDHT, mkDRI, mkAPP0..mkAPP15, mkCOM];
                      Inc(FScanCount);
                      Result := DecodeScan;
                      if Result <> JPEG_OK then
                        Break;

                      FEnabledMarkers := FEnabledMarkers + [mkSOS, mkEOI];
                    end;
                else
                  Result := JPEG_UNSUPPORTED_COMRESSION_METHOD;
                  {$IFDEF DEBUG}
                  Error('Compression method ' + MarkerToString(FSOF.Type_) + ' is not supported.', 0);
                  {$ENDIF}
                  Break;
                end;
              end;
          end;
        end;
      end;
    end;
end;

{$IFDEF DEBUG}
procedure TdecJpegImage.Error(const AMessage: string; AOffset: Integer);
begin
  {raise EJpegDecoderException.Create(AMessage + ' Stream position: ' + IntToHex(FPosition - AOffset, 8)
    + ', MCUIndex: ' + IntToStr(FCurrentMCUIndex));{}
end;
{$ENDIF}

function TdecJpegImage.Read(ABuffer: PByte; ASize: Cardinal): Cardinal;
var
  CopySize: Cardinal;
begin
  Result := 0;
  while ASize > 0 do
    begin
      if FBufferAvailableSize = 0 then
        begin
          FBufferAvailableSize := FStream.Read(FBuffer^, FBufferSize);
          FBufferPos := FBuffer;
          if FBufferAvailableSize = 0 then Exit;
        end;
      if ASize > FBufferAvailableSize then CopySize := FBufferAvailableSize
                                      else CopySize := ASize;
      CopyMemory(ABuffer, FBufferPos, CopySize);
      Inc(ABuffer, CopySize);
      Dec(ASize, CopySize);
      Inc(FBufferPos, CopySize);
      Dec(FBufferAvailableSize, CopySize);
      Inc(Result, CopySize);
    end
end;

function TdecJpegImage.ReadByte(out AByte: Byte): Cardinal;
begin
  if FBufferAvailableSize > 0 then
    begin
      AByte := FBufferPos^;
      Inc(FBufferPos);
      Dec(FBufferAvailableSize);
      Result := JPEG_OK
    end
  else
    if Read(@AByte, 1) = 1 then Result := JPEG_OK
                           else Result := JPEG_UNEXPECTED_EOF;
end;

function TdecJpegImage.ReadByte(out AByte: Integer): Cardinal;
begin
  if FBufferAvailableSize > 0 then
    begin
      AByte := FBufferPos^;
      Inc(FBufferPos);
      Dec(FBufferAvailableSize);
      Result := JPEG_OK
    end
  else
    begin
      AByte := 0;
      if Read(@AByte, 1) = 1 then Result := JPEG_OK
                             else Result := JPEG_UNEXPECTED_EOF;
    end;
end;

function TdecJpegImage.PreviewByte(out AByte: Integer): Cardinal;
begin
  if FBufferAvailableSize > 0 then
    begin
      AByte := FBufferPos^;
      Result := JPEG_OK;
    end
  else
    Result := JPEG_DATA_ERROR;
end;

function TdecJpegImage.ReadMarker(out AMarker: Byte): Cardinal;
var
  Sign: Byte;
begin
  Result := ReadByte(Sign);
  if Result <> JPEG_OK then
    begin
      {$IFDEF DEBUG}
      Error('Marker FF expected but EOF found.', 0);
      {$ENDIF}
      Exit;
    end;
  if Sign <> $FF then
    begin
      Result := JPEG_DATA_ERROR;
      {$IFDEF DEBUG}
      Error('Marker FF expected but ' + IntToHex(Sign, 2) + ' found.', 1);
      {$ENDIF}
      Exit;
    end;

  while True do
    begin
      Result := ReadByte(AMarker);
      if Result <> JPEG_OK then
        begin
          {$IFDEF DEBUG}
          Error('Marker code expected but EOF found.', 0);
          {$ENDIF}
          Exit;
        end;
      case AMarker of
        0, $FF:;
      else
        Exit;
      end;
    end;
end;

function TdecJpegImage.ReadSize(AMarker: Byte; out ASize: Word): Cardinal;
var
  SizeH, SizeL: Byte;
begin
  Result := ReadByte(SizeH);
  if Result <> JPEG_OK then
    begin
      {$IFDEF DEBUG}
      Error('Segment size expected but EOF found.', 0);
      {$ENDIF}
      Exit;
    end;
  Result := ReadByte(SizeL);
  if Result <> JPEG_OK then
    begin
      {$IFDEF DEBUG}
      Error('Segment size expected but EOF found.', 0);
      {$ENDIF}
      Exit;
    end;
  ASize := (SizeH shl 8) or (SizeL);
  if ASize < 2 then
    begin
      Result := JPEG_DATA_ERROR;
      {$IFDEF DEBUG}
      Error('Invalid segment size.', -2);
      {$ENDIF}
      Exit;
    end;
  Dec(ASize, 2);
end;

function TdecJpegImage.ReadSegment(ASize: Word): Word;
begin
  if not Assigned(FSegment) then
    GetMem(FSegment, $FFFF);
  Result := Read(FSegment, ASize);
end;

type
  TsdZigZagArray = array[0..63 + 16] of byte;

const
  cJpegForwardZigZag8x8: TsdZigZagArray =
    ( 0,  1,  5,  6, 14, 15, 27, 28,
      2,  4,  7, 13, 16, 26, 29, 42,
      3,  8, 12, 17, 25, 30, 41, 43,
      9, 11, 18, 24, 31, 40, 44, 53,
     10, 19, 23, 32, 39, 45, 52, 54,
     20, 22, 33, 38, 46, 51, 55, 60,
     21, 34, 37, 47, 50, 56, 59, 61,
     35, 36, 48, 49, 57, 58, 62, 63,
      0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0);

  cJpegInverseZigZag8x8: TsdZigZagArray =
    ( 0,  1,  8, 16,  9,  2,  3, 10,
     17, 24, 32, 25, 18, 11,  4,  5,
     12, 19, 26, 33, 40, 48, 41, 34,
     27, 20, 13,  6,  7, 14, 21, 28,
     35, 42, 49, 56, 57, 50, 43, 36,
     29, 22, 15, 23, 30, 37, 44, 51,
     58, 59, 52, 45, 38, 31, 39, 46,
     53, 60, 61, 54, 47, 55, 62, 63,
      0,  0,  0,  0,  0,  0,  0,  0,
      0,  0,  0,  0,  0,  0,  0,  0);

const
  cIAccConstBits = 9;
  cIAccRangeBits = cIAccConstBits + 3;
  // we use 9 bits of precision, so must multiply by 2^9
  cIAccConstScale = 1 shl cIAccConstBits;

  cCenterSample = 128;
  cMaxSample    = 255;

function IsSegment(ASegment: PByte; const ASignature: AnsiString): Boolean;
var
  Index: Integer;
  Signature: PAnsiChar;
begin
  Signature := PAnsiChar(ASignature);
  for Index := 1 to Length(ASignature) do
    begin
      Result := ASegment^ = Byte(Signature^);
      if not Result then Exit;
      Inc(ASegment);
      Inc(Signature);
    end;
  Result := True;
end;

procedure TdecJpegImage.ReadAPP(AMarker: Byte; ASize: Word);
begin
  if (AMarker = mkAPP0) and (ASize >= 14) and IsSegment(FSegment, 'JFIF'#0) then
    FJFIFFound := True
  else

  if (AMarker = mkAPP14) and (ASize = 12) and IsSegment(FSegment, 'Adobe'#0) then
    begin
      FAdobeFound := True;
      FAdobeTransform := FSegment[11];
    end
  else

  if (AMarker = mkAPP1) and (ASize > 5) and IsSegment(FSegment, 'G3FAX') then
    FG3FAXFound := True
  else

  if (AMarker = mkAPP2) and (ASize > 11) and IsSegment(FSegment, 'ICC_PROFILE') then
    FICC_PROFILEFound := True
  else
  ;
end;

function TdecJpegImage.ReadDQT(ASize: Word): Cardinal;
var
  //Count: Integer;
  Pos: PByte;
  B: Byte;
  Index: Integer;
  ItemSize: Integer;
  TableSize: Integer;
  Table: PdecDQTTable;
  ItemIndex: Integer;
  Index2: Integer;
begin
  Result := JPEG_DATA_ERROR;
  //Count := 0;
  Pos := FSegment;
  {$IFDEF DEBUG}
  //ItemSize := 0; // Make compiler happy
  {$ENDIF}
  while ASize > 0 do
    begin
      (*if Count = 4 then
        begin
          Result := JPEG_DATA_ERROR;
          Error_{$IFDEF DEBUG}('DQT section contains too much tables.', ASize + 4){$ENDIF};
          //Exit;
        end;*)
      B := Pos^;

      Index := B and $F;
      if Index > 4 then
        begin
          {$IFDEF DEBUG}
          Error('DQT section table has invalid index ' + IntToStr(Index) + '.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
      Table := @FDQTTables[Index];

      case B and $F0 of
        $00: ItemSize := 1;
        $10: ItemSize := 2;
      else
        {$IFDEF DEBUG}
        Error('DQT section table has invalid item size ' + IntToStr((B and $F0) shr 4) + '.', ASize + 4);
        {$ENDIF}
        Exit;
        ItemSize := 0; // Make compiler happy
      end;

      Inc(Pos);
      Dec(ASize);

      TableSize := ItemSize * 64;
      if TableSize > ASize then
        begin
          {$IFDEF DEBUG}
          Error('DQT section too small.', ASize + 4);
          {$ENDIF}
          Exit;
        end;

      if ItemSize = 1 then
        for ItemIndex := 0 to 63 do
          begin
            Table.Values[ItemIndex] := Pos^;
            Inc(Pos);
          end
      else
        for ItemIndex := 0 to 63 do
          begin
            Table.Values[ItemIndex] := PWord(Pos)^;
            Inc(Pos, 2);
          end;

      Table.Inited := True;

      Dec(ASize, TableSize);
      //Inc(Count);

      for Index := 0 to 63 do
        begin
          Index2 := cJpegInverseZigZag8x8[Index];
          // give correct bit precision
          Table.ValuesEx[Index2] := Table.Values[Index] * cIAccConstScale;
        end;
    end;

  Result := JPEG_OK;
end;

function IntToBin(AInt: DWORD; AMinLen: Integer): string;
begin
  if AInt = 0 then
    Result := '0'
  else
    begin
      Result := '';
      while AInt <> 0 do
        begin
          if AInt mod 2 = 0 then Result := '0' + Result
                            else Result := '1' + Result;
          AInt := AInt shr 1;
        end;
      while Length(Result) < AMinLen do
        Result := '0' + Result;
    end;
end;

function TdecJpegImage.InitDHT(ATable: PdecDHTTable): Cardinal;
var
  HuffmanCodeLen: Integer;
  ValueCount: Integer;
  ValueIndex: Integer;
  TotalValueCount: Integer;
  MaxHuffmanCodeLen: Integer;
  HuffmanCode: Integer;
  FastHuffman: Integer;
  FastValue: Integer;
  FastIndex: Integer;
begin
  Result := JPEG_OK;
  if ATable.Filled then Exit;

  ATable.MinHuffmanLen := 1;

  for HuffmanCodeLen := 1 to 16 do
    begin
      if ATable.HuffmanCodes[HuffmanCodeLen].Count > 0 then Break;
      Inc(ATable.MinHuffmanLen);
    end;

  TotalValueCount := 0;
  MaxHuffmanCodeLen := 2;
  HuffmanCode := 0;
  for HuffmanCodeLen := 1 to 16 do
    begin
      ValueCount := ATable.HuffmanCodes[HuffmanCodeLen].Count;
      if ValueCount > MaxHuffmanCodeLen then
        begin
          Result := JPEG_DATA_ERROR;
          {$IFDEF DEBUG}
          Error('DHT section error.', 0);
          {$ENDIF}
          Exit;
        end;

      for ValueIndex := 0 to ValueCount - 1 do
        begin
          if TotalValueCount = 256 then
            begin
              {$IFDEF DEBUG}
              Error('DHT section table too large.', 0);
              {$ENDIF}
              Result := JPEG_DATA_ERROR;
              Exit;
            end;

          if ValueIndex = 0 then
            begin
              ATable.HuffmanCodes[HuffmanCodeLen].MinValue := HuffmanCode;
              ATable.HuffmanCodes[HuffmanCodeLen].MinIndex := TotalValueCount;
            end;
          ATable.HuffmanCodes[HuffmanCodeLen].MaxValue := HuffmanCode;

          if HuffmanCodeLen < 9 then
            begin
              FastHuffman := HuffmanCode shl (8 - HuffmanCodeLen);
              FastValue := ATable.Values[ATable.HuffmanCodes[HuffmanCodeLen].MinIndex + (HuffmanCode - ATable.HuffmanCodes[HuffmanCodeLen].MinValue)];
              for FastIndex := 0 to (1 shl (8 - HuffmanCodeLen)) - 1 do
                with ATable.FastValues[FastHuffman or FastIndex] do
                  begin
                    Value := FastValue;
                    BitCount := HuffmanCodeLen;
                  end;
            end;

          Inc(HuffmanCode);
          Inc(TotalValueCount);
        end;
      HuffmanCode := HuffmanCode * 2;
      MaxHuffmanCodeLen := MaxHuffmanCodeLen * 2;
    end;

  ATable.Filled := True;
end;

function TdecJpegImage.ReadDHT(ASize: Word): Cardinal;
var
  {$IFDEF DEBUG}
  TableIndex: Integer;
  {$ENDIF}
  Pos: PByte;
  B: Byte;
  Index: Integer;
  Table: PdecDHTTable;
  HuffmanCodeLen: Integer;
  ValueCount: Integer;
  ValueIndex: Integer;
  TotalValueCount: Integer;
begin
  Result := JPEG_DATA_ERROR;
  {$IFDEF DEBUG}
  TableIndex := 0;
  {$ENDIF}
  Pos := FSegment;
  while ASize > 0 do
    begin
      B := Pos^;

      Index := B and $F;
      if Index > 4 then
        begin
          {$IFDEF DEBUG}
          Error('DHT section table ' + IntToStr(TableIndex) + ' has invalid index ' + IntToStr(Index) + '.', ASize + 4);
          {$ENDIF}
          Exit;
        end;

      case B and $F0 of
        $00: Table := @FDC_DHTTables[Index];
        $10: Table := @FAC_DHTTables[Index];
      else
        {$IFDEF DEBUG}
        Error('DHT section table ' + IntToStr(TableIndex) + ' has invalid table type ' + IntToStr((B and $F0) shr 4) + '.', ASize + 4);
        {$ENDIF}
        Exit;
        Table := nil; // Make compiler happy
      end;
      ZeroMemory(Table, SizeOf(Table^));
      Table.MinHuffmanLen := 1;

      Inc(Pos);
      Dec(ASize);

      if ASize < 16 then
        begin
          {$IFDEF DEBUG}
          Error('DHT section ' + IntToStr(TableIndex) + ' too small.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
      for HuffmanCodeLen := 1 to 16 do
        begin
          Table.HuffmanCodes[HuffmanCodeLen].Count := Pos^;
          Inc(Pos);
        end;
      for HuffmanCodeLen := 1 to 16 do
        begin
          if Table.HuffmanCodes[HuffmanCodeLen].Count > 0 then Break;
          Inc(Table.MinHuffmanLen);
        end;

      Dec(ASize, 16);

      TotalValueCount := 0;
      for HuffmanCodeLen := 1 to 16 do
        begin
          ValueCount := Table.HuffmanCodes[HuffmanCodeLen].Count;
          if ASize < ValueCount then
            begin
              {$IFDEF DEBUG}
              Error('DHT section ' + IntToStr(TableIndex) + ' too small.', ASize + 4);
              {$ENDIF}
              Exit;
            end;
          for ValueIndex := 0 to ValueCount - 1 do
            begin
              if TotalValueCount > 255 then
                begin
                  {$IFDEF DEBUG}
                  Error('DHT section ' + IntToStr(TableIndex) + ' has too many values.', ASize + 4);
                  {$ENDIF}
                  Exit;
                end;

              Table.Values[TotalValueCount] := Pos^;
              Inc(TotalValueCount);
              Inc(Pos);
            end;
          Dec(ASize, ValueCount);
        end;

      Table.Inited := True;
      Table.Filled := False;

      {$IFDEF DEBUG}
      Inc(TableIndex);
      {$ENDIF}
    end;

  Result := JPEG_OK;
end;


function TdecJpegImage.ReadDRI(ASize: Word): Cardinal;
begin
  Result := JPEG_DATA_ERROR;
  if ASize <> 2 then
    begin
      {$IFDEF DEBUG}
      Error('DRI section has invalid size ' + IntToStr(ASize) , ASize + 4);
      {$ENDIF}
      Exit;
    end;
  FRestartInterval := Swap16(PWord(FSegment)^);
  AfterRestart;
  Result := JPEG_OK;
end;

function TdecJpegImage.ReadSOF(AMarker: Byte; ASize: Word): Cardinal;
var
  Pos: PByte;
  ComponentIndex: Integer;
  Sampling: Integer;
begin
  Result := JPEG_DATA_ERROR;

  if FSOF.Inited then
    begin
      {$IFDEF DEBUG}
      Error('SOF was already inited.', ASize + 4);
      {$ENDIF}
      Exit;
    end;

  FSOF.Type_ := AMarker;

  if ASize < 6 then
    begin
      {$IFDEF DEBUG}
      Error('SOF section too small.', ASize + 4);
      {$ENDIF}
      Exit;
    end;

  Pos := FSegment;
  FSOF.SamplePrecision := Pos^; Inc(Pos);
  if FSOF.SamplePrecision <> 8 then
    begin
      {$IFDEF DEBUG}
      Error('SOF.SamplePrecision value ' + IntToStr(FSOF.SamplePrecision) + ' is not supported.', ASize + 4);
      {$ENDIF}
      Result := JPEG_UNSUPPORTED_COMRESSION_METHOD;
      Exit;
    end;
  FSOF.ImageHeight := Swap16(PWord(Pos)^); Inc(Pos, 2);
  if FSOF.ImageHeight = 0 then
    FUnknownHeight := True;
  FSOF.ImageWidth := Swap16(PWord(Pos)^); Inc(Pos, 2);
  if FSOF.ImageWidth = 0 then
    begin
      {$IFDEF DEBUG}
      Error('SOF.ImageWidth value ' + IntToStr(FSOF.ImageWidth) + ' is not supported.', ASize + 4);
      {$ENDIF}
      Exit;
    end;
  FSOF.ComponentCount := Pos^; Inc(Pos);
  if (FSOF.ComponentCount < 1) or (FSOF.ComponentCount > 4) then
    begin
      {$IFDEF DEBUG}
      Error('SOF.ComponentCount value ' + IntToStr(FSOF.ComponentCount) + ' is not supported.', ASize + 4);
      {$ENDIF}
      Exit;
    end;
  Dec(ASize, 6);

  FSOF.MaxHorzSampling := 0;
  FSOF.MaxVertSampling := 0;
  for ComponentIndex := 0 to FSOF.ComponentCount - 1 do
    begin
      if ASize < 3 then
        begin
          {$IFDEF DEBUG}
          Error('SOF section too small.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
      FSOF.Components[ComponentIndex].ID := Pos^;
      FComponentIDs := FComponentIDs + AnsiChar(Pos^);
      Inc(Pos);

      Sampling := Pos^ and $0F;
      if (Sampling <> 1) and (Sampling <> 2) and (Sampling <> 4) and (Sampling <> 8) then
        begin
          {$IFDEF DEBUG}
          Error('VerticalSampling value ' + IntToStr(Sampling) + ' is not supported.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
      FSOF.Components[ComponentIndex].VertSampling := Sampling;
      if Sampling > FSOF.MaxVertSampling then
        FSOF.MaxVertSampling := Sampling;

      Sampling := (Pos^ and $F0) shr 4;
      if (Sampling <> 1) and (Sampling <> 2) and (Sampling <> 4) and (Sampling <> 8) then
        begin
          {$IFDEF DEBUG}
          Error('HorizontalSampling value ' + IntToStr(Sampling) + ' is not supported.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
      FSOF.Components[ComponentIndex].HorzSampling := Sampling;
      if Sampling > FSOF.MaxHorzSampling then
        FSOF.MaxHorzSampling := Sampling;
      Inc(Pos);

      FSOF.Components[ComponentIndex].DQT_TableIndex := Pos^;
      Inc(Pos);
      Dec(ASize, 3);
    end;

  if ASize <> 0 then
    begin
      {$IFDEF DEBUG}
      Error('SOF section too large.', ASize + 4);
      {$ENDIF}
      Exit;
    end;

  FSOF.Inited := True;

  FSOF.MCUWidth := FSOF.MaxHorzSampling * 8;
  FSOF.MCUHeight := FSOF.MaxVertSampling * 8;

  Result := JPEG_OK;
end;

function TdecJpegImage.ReadSOS(ASize: Word): Cardinal;
var
  Pos: PByte;
  Component: Byte;
  ComponentIndex: Integer;
  TableIndexes: Byte;
  TableIndex: Byte;
  SOFIndex: Integer;
  SOFIndexFound: Boolean;
  SOFComponent: PdecSOFComponent;
  IsDCBand: boolean;
begin
  Result := JPEG_DATA_ERROR;

  if ASize < 1 then
    begin
      {$IFDEF DEBUG}
      Error('SOS section too small.', ASize + 4);
      {$ENDIF}
      Exit;
    end;

  Pos := FSegment;
  FSOS.ComponentCount := Pos^; Inc(Pos); Dec(ASize);

  if ASize < FSOS.ComponentCount * 2 then
    begin
      {$IFDEF DEBUG}
      Error('SOS section too small.', ASize + 4);
      {$ENDIF}
      Exit;
    end;

  FSOS.MaxHorzSampling := 0;
  FSOS.MaxVertSampling := 0;
  for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
    begin
      FSOS.Components[ComponentIndex].PrevDC := 0;
      Component := Pos^; Inc(Pos);
      FSOS.Components[ComponentIndex].ID := Component;
      SOFIndexFound := False;
      for SOFIndex := 0 to FSOF.ComponentCount - 1 do
        begin
          SOFComponent := @FSOF.Components[SOFIndex];
          if SOFComponent.ID = Component then
            begin
              FSOS.Components[ComponentIndex].SOFIndex := SOFIndex;
              with FSOS.Components[ComponentIndex] do
                begin
                  VertSampling := SOFComponent.VertSampling;
                  if VertSampling > FSOS.MaxVertSampling then
                    FSOS.MaxVertSampling := VertSampling;
                  HorzSampling := SOFComponent.HorzSampling;
                  if HorzSampling > FSOS.MaxHorzSampling then
                    FSOS.MaxHorzSampling := HorzSampling;
                  DQT_TableIndex := SOFComponent.DQT_TableIndex;
                end;
              SOFIndexFound := True;
              Break;
            end;
        end;
      if not SOFIndexFound then
        begin
          {$IFDEF DEBUG}
          Error('Invalid component ' + IntToHex(Component, 2) + '.', ASize + 4);
          {$ENDIF}
          Exit;
        end;

      TableIndexes := Pos^; Inc(Pos);

      TableIndex := (TableIndexes and $F0) shr 4;
      FSOS.Components[ComponentIndex].DHT_DCTableIndex := TableIndex;
      if TableIndex > 3 then
        begin
          {$IFDEF DEBUG}
          Error('Invalid DC table index ' + IntToStr(TableIndex) + '.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
      if ((FSOF.Type_ = mkSOF0) or (FSOF.Type_ = mkSOF1)) and not FDC_DHTTables[TableIndex].Inited then
        begin
          {$IFDEF DEBUG}
          Error('Invalid DC table index ' + IntToStr(TableIndex) + '.', ASize + 4);
          {$ENDIF}
          Exit;
        end;

      TableIndex := TableIndexes and $F;
      FSOS.Components[ComponentIndex].DHT_ACTableIndex := TableIndex;
      if TableIndex > 3 then
        begin
          {$IFDEF DEBUG}
          Error('Invalid AC table index ' + IntToStr(TableIndex) + '.', ASize + 4);
          {$ENDIF}
          Exit;
        end;
        if ((FSOF.Type_ = mkSOF0) or (FSOF.Type_ = mkSOF1)) and not FAC_DHTTables[TableIndex].Inited then
          begin
            {$IFDEF DEBUG}
            Error('Invalid AC table index ' + IntToStr(TableIndex) + '.', ASize + 4);
            {$ENDIF}
            Exit;
          end;
    end;
  Dec(ASize, FSOS.ComponentCount * 2);

  if ASize <> 3 then
    begin
      {$IFDEF DEBUG}
      Error('SOS section too large.', ASize + 4);
      {$ENDIF}
      Exit;
    end;
  FSOS.SpectralStart := Pos^; Inc(Pos);
  FSOS.SpectralEnd := Pos^; Inc(Pos);
  FSOS.ApproxHigh := Pos^ shr 4;
  FSOS.ApproxLow := Pos^ and $F;

  for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
    with FSOS.Components[ComponentIndex] do
      begin
        DUWidth := (FSOF.MaxHorzSampling div HorzSampling) * 8;
        DUHeight := (FSOF.MaxVertSampling div VertSampling) * 8;
      end;

  if FSOF.Type_ = mkSOF2 then
    begin
      if FSOS.SpectralStart = 0 then
        if FSOS.SpectralEnd <> 0 then Exit;
      if FSOS.SpectralEnd = 0 then
        if FSOS.SpectralStart <> 0 then Exit;
      if FSOS.SpectralEnd < FSOS.SpectralStart then Exit;
      if FSOS.SpectralStart > 0 then
        if FSOS.ComponentCount > 1 then Exit;
      if FSOS.SpectralEnd > 63 then Exit;
      if FSOS.ApproxHigh > 13 then Exit;
      if FSOS.ApproxLow > 13 then Exit;
      if FSOS.ApproxHigh > 0 then
        if FSOS.ApproxHigh - FSOS.ApproxLow <> 1 then Exit;

      IsDCBand := FSOS.SpectralStart = 0;
      if not IsDCBand then
        if FSOS.ComponentCount <> 1 then Exit;
    end;

  if FSOS.ComponentCount = 1 then
    begin
      FSOS.MCUWidth := FSOS.Components[0].DUWidth;
      FSOS.MCUHeight := FSOS.Components[0].DUHeight;
      FSOS.MCUHorzCount := (FSOF.ImageWidth + FSOS.MCUWidth - 1) div FSOS.MCUWidth;
      FSOS.MCUVertCount := (FSOF.ImageHeight + FSOS.MCUHeight - 1) div FSOS.MCUHeight;
      with FSOS.Components[0] do
        begin
          DUHorzCount := 1;
          DUVertCount := 1;
        end;
    end
  else
    begin
      FSOS.MCUWidth := 8 * FSOF.MaxHorzSampling;
      FSOS.MCUHeight := 8 * FSOF.MaxVertSampling;
      FSOS.MCUHorzCount := (FSOF.ImageWidth + FSOS.MCUWidth - 1) div FSOS.MCUWidth;
      FSOS.MCUVertCount := (FSOF.ImageHeight + FSOS.MCUHeight - 1) div FSOS.MCUHeight;

      for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
        with FSOS.Components[ComponentIndex] do
          begin
            DUHorzCount := FSOS.MCUWidth div DUWidth;
            DUVertCount := FSOS.MCUHeight div DUHeight;
          end;
    end;

  {if not FSOS.Inited then
    begin
      FMCUWidth := FSOS.MCUWidth;
      FMCUHeight := FSOS.MCUHeight;
    end;}

  FSOS.Inited := True;

  Result := JPEG_OK;
end;

const
  MirrorByte: array[Byte] of Integer = (
    $00, $80, $40, $C0, $20, $A0, $60, $E0, $10, $90, $50, $D0, $30, $B0, $70, $F0,
    $08, $88, $48, $C8, $28, $A8, $68, $E8, $18, $98, $58, $D8, $38, $B8, $78, $F8,
    $04, $84, $44, $C4, $24, $A4, $64, $E4, $14, $94, $54, $D4, $34, $B4, $74, $F4,
    $0C, $8C, $4C, $CC, $2C, $AC, $6C, $EC, $1C, $9C, $5C, $DC, $3C, $BC, $7C, $FC,
    $02, $82, $42, $C2, $22, $A2, $62, $E2, $12, $92, $52, $D2, $32, $B2, $72, $F2,
    $0A, $8A, $4A, $CA, $2A, $AA, $6A, $EA, $1A, $9A, $5A, $DA, $3A, $BA, $7A, $FA,
    $06, $86, $46, $C6, $26, $A6, $66, $E6, $16, $96, $56, $D6, $36, $B6, $76, $F6,
    $0E, $8E, $4E, $CE, $2E, $AE, $6E, $EE, $1E, $9E, $5E, $DE, $3E, $BE, $7E, $FE,
    $01, $81, $41, $C1, $21, $A1, $61, $E1, $11, $91, $51, $D1, $31, $B1, $71, $F1,
    $09, $89, $49, $C9, $29, $A9, $69, $E9, $19, $99, $59, $D9, $39, $B9, $79, $F9,
    $05, $85, $45, $C5, $25, $A5, $65, $E5, $15, $95, $55, $D5, $35, $B5, $75, $F5,
    $0D, $8D, $4D, $CD, $2D, $AD, $6D, $ED, $1D, $9D, $5D, $DD, $3D, $BD, $7D, $FD,
    $03, $83, $43, $C3, $23, $A3, $63, $E3, $13, $93, $53, $D3, $33, $B3, $73, $F3,
    $0B, $8B, $4B, $CB, $2B, $AB, $6B, $EB, $1B, $9B, $5B, $DB, $3B, $BB, $7B, $FB,
    $07, $87, $47, $C7, $27, $A7, $67, $E7, $17, $97, $57, $D7, $37, $B7, $77, $F7,
    $0F, $8F, $4F, $CF, $2F, $AF, $6F, $EF, $1F, $9F, $5F, $DF, $3F, $BF, $7F, $FF);

procedure TdecJpegImage.InitBitReaded;
begin
  FAvailableBitCount := 0;
  FRealAvailableBitCount := 0;
end;

procedure TdecJpegImage.AfterRestart;
var
  ComponentIndex: Integer;
begin
  InitBitReaded;
  FRestartCounter := 0;
  // Init DC
  for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
    FSOS.Components[ComponentIndex].PrevDC := 0;
end;

function IsRSTMarker(AByte: Byte): Boolean; inline;
begin
  Result := (AByte >= mkRST0) and (AByte <= mkRST7);
end;

function TdecJpegImage.FillBits: Cardinal;
var
  NextByte: Integer;
begin
  Result := ReadByte(FBits);
  if Result <> JPEG_OK then
    begin
      {$IFDEF DEBUG}
      Error('Unexpected EOF.', 0);
      {$ENDIF}
      Exit;
    end;

  if FBits = $FF then
    begin
      //while True do
        begin
          Result := ReadByte(NextByte);
          if Result <> JPEG_OK then
            begin
              {$IFDEF DEBUG}
              Error('Unexpected EOF.', 0);
              {$ENDIF}
              Exit;
            end;
          //if NextByte <> $FF then Break;
        end;
      if NextByte <> 0 then
        begin
          if (FRestartInterval > 0) and IsRSTMarker(NextByte) then
            Result := NextByte
          else
          if FUnknownHeight and (NextByte = mkDNL) then
            Result := NextByte
          else
            if NextByte = $D9 then
              Result := JPEG_UNEXPECTED_EOI
            else
              Result := JPEG_DATA_ERROR;
          Exit;
        end;
    end;

  FBits := FBits shl 8;
  FAvailableBitCount := 8;
  FRealAvailableBitCount := 8;
  if (PreviewByte(NextByte) = JPEG_OK) and (NextByte <> $FF) then
    begin
      FBits := FBits or NextByte;
      FRealAvailableBitCount := 16;
    end;
end;

function TdecJpegImage.ReadBit(out ABit: Integer): Cardinal;
begin
  if FAvailableBitCount = 0 then
    begin
      Result := FillBits;
      if Result <> JPEG_OK then Exit;
    end;

  if FBits and $8000 = 0 then ABit := 0
                         else ABit := 1;
  FBits := (FBits shl 1) and $FFFF;
  Dec(FAvailableBitCount);
  Dec(FRealAvailableBitCount);
  Result := JPEG_OK;
end;

function TdecJpegImage.ReadBits(ACount: Integer; out ABits: Integer): Cardinal;
var
  Bit: Integer;
  CopyCount: Integer;
begin
  {$IFDEF DEBUG}
  if ACount = 0 then
    raise Exception.Create('You cannot pass ZERO in ACount param in ReadBits.');
  {$ENDIF}

  ABits := 0;
  while ACount > 0 do
    begin
      if FAvailableBitCount = 0 then
        begin
          Result := FillBits;
          if Result <> JPEG_OK then Exit;
        end;

      if ACount > FAvailableBitCount then CopyCount := FAvailableBitCount
                                     else CopyCount := ACount;
      Bit := FBits shr (16 - CopyCount);
      FBits := (FBits shl CopyCount) and $FFFF;
      Dec(FAvailableBitCount, CopyCount);
      Dec(FRealAvailableBitCount, CopyCount);

      ABits := (ABits shl CopyCount) or Bit;
      Dec(ACount, CopyCount);
    end;
  Result := JPEG_OK;
end;

function TdecJpegImage.ReadHuffman(ATable: PdecDHTTable; out AValue: Integer): Cardinal;
var
  FastValueIndex: Integer;
  FastSkip: Integer;
  NextByte: Integer;
  HuffmanCode: Integer;
  HuffmanCodeLen: Integer;
  Bit: Integer;
  DHTValue: PdecDHTValue;
  Delta: Integer;
begin
  HuffmanCodeLen := ATable.MinHuffmanLen;

  if (FAvailableBitCount = 0) and (FRealAvailableBitCount < 8) then
    begin
      Result := FillBits;
      if Result <> JPEG_OK then Exit;
    end;

  if FRealAvailableBitCount >= 8 then
    begin
      FastValueIndex := FBits shr 8;
      if ATable.FastValues[FastValueIndex].BitCount <> 0 then
        begin
          AValue := ATable.FastValues[FastValueIndex].Value;
          FastSkip := ATable.FastValues[FastValueIndex].BitCount;
          while FastSkip > 0 do
            begin
              if FAvailableBitCount = 0 then
                begin
                  ReadByte(FBits);
                  FBits := FBits shl 8;
                  FAvailableBitCount := 8;
                  FRealAvailableBitCount := 8;
                  if (PreviewByte(NextByte) = JPEG_OK) and (NextByte <> $FF) then
                    begin
                      FBits := FBits or NextByte;
                      FRealAvailableBitCount := 16;
                    end;
                end;

              if FAvailableBitCount > 0 then
                begin
                  if FAvailableBitCount >= FastSkip then
                    begin
                      FBits := (FBits shl FastSkip) and $FFFF;
                      Dec(FAvailableBitCount, FastSkip);
                      Dec(FRealAvailableBitCount, FastSkip);
                      FastSkip := 0;
                    end
                  else
                    begin
                      Dec(FastSkip, FAvailableBitCount);
                      Dec(FRealAvailableBitCount, FAvailableBitCount);
                      FAvailableBitCount := 0;
                    end;
                end;
            end;

          Result := JPEG_OK;
          Exit;
        end;
    end;

  if HuffmanCodeLen = 1 then Result := ReadBit(HuffmanCode)
                        else Result := ReadBits(HuffmanCodeLen, HuffmanCode);
  if Result <> JPEG_OK then Exit;

  while True do
    begin
      DHTValue := @ATable.HuffmanCodes[HuffmanCodeLen];
      if (DHTValue.Count > 0) and (HuffmanCode <= DHTValue.MaxValue) then
        begin
          Delta := HuffmanCode - DHTValue.MinValue;
          AValue := ATable.Values[DHTValue.MinIndex + Delta];
          Break;
        end;

      Result := ReadBit(Bit);
      if Result <> JPEG_OK then Exit;

      if HuffmanCodeLen = 16 then
        begin
          Result := JPEG_DATA_ERROR;
          {$IFDEF DEBUG}
          Error('Data error.', 0);
          {$ENDIF}
          Exit;
        end;

      HuffmanCode := (HuffmanCode shl 1) or Bit;
      Inc(HuffmanCodeLen);
    end;
end;

{$IFDEF JPEG_CODEC_MODE}
function TdecJpegImage.ReadDC(ATable: PdecDHTTable; out ADCLen, ADC: Integer): Cardinal;
{$IFDEF DEBUG}
var
  CurrentPos: string;
{$ENDIF}
begin
  {$IFDEF DEBUG}
  CurrentPos := GetCurrentPos;
  {$ENDIF}
  Result := ReadHuffman(ATable, ADCLen);
  if Result <> JPEG_OK then Exit;

  ADC := 0;
  if ADCLen > 0 then
    Result := ReadBits(ADCLen, ADC);
end;

function TdecJpegImage.ReadAC(ATable: PdecDHTTable; out AZeroCount, AACLen, AAC: Integer): Cardinal;
{$IFDEF DEBUG}
var
  CurrentPos: string;
{$ENDIF}
begin
  {$IFDEF DEBUG}
  CurrentPos := GetCurrentPos;
  {$ENDIF}
  Result := ReadHuffman(ATable, AACLen);
  if Result <> JPEG_OK then Exit;

  AZeroCount := AACLen shr 4;
  AACLen := AACLen and $F;
  AAC := 0;
  if AACLen > 0 then
    Result := ReadBits(AACLen, AAC);
end;
{$ENDIF}

function TdecJpegImage.GetValues(AComponentIndex, AComponentIndex2, AMCUHorzIndex, AMCUVertIndex: Integer): PdecDataUnit;
var
  SOFIndex: Integer;
  NewHeight: Integer;
begin
  if FUnknownHeight then
    begin
      NewHeight := AMCUVertIndex + 1;
      FSOS.MCUVertCount := NewHeight;
      NewHeight := NewHeight * FSOS.MCUHeight;
      FSOF.ImageHeight := NewHeight;
    end;

  SOFIndex := FSOS.Components[AComponentIndex].SOFIndex;
  if FUnknownHeight then
    begin
      NewHeight := AMCUVertIndex + 1;
      if FMCU[SOFIndex].MCUVertCount < NewHeight then
        FMCU[SOFIndex].MCUVertCount := NewHeight;
    end;
  Result := FMCU[SOFIndex].Values[AMCUHorzIndex, AMCUVertIndex, AComponentIndex2];
end;

function TdecJpegImage.DetectColorSpace: TsdJpegColorSpace;
begin
  Result := jcAutoDetect;
  if not FSOF.Inited then Exit;

  Result := FColorSpace;
  if Result <> jcAutoDetect then Exit;

  // Defaults: Based on component count
  case FSOF.ComponentCount of
    1: Result := jcGray;
    2: Result := jcGrayA;
    3: Result := jcYCbCr;
    4: Result := jcYCCK;
  end;

  // Check JFIF marker
  if FJFIFFound then
    // We have a JFIF marker: if component count is 1 or 3, above assumptions are correct
    if (FSOF.ComponentCount = 1) or (FSOF.ComponentCount = 3) then
      Exit;

  // Check Adobe APP14 marker
  if FAdobeFound then
    begin
      // We have an Adobe APP14 marker
      case FAdobeTransform of
        0:
          begin
            case FSOF.ComponentCount of
              3: Result := jcRGB;
              4: Result := jcCMYK;
            end;
          end;
        1: Result := jcYCbCr;
        2: Result := jcYCCK;
      end;
      Exit;
    end;

  // Check for ITU G3FAX format
  if FG3FAXFound then
    begin
      Result := jcITUCieLAB;
      Exit;
    end;

{  EXIF := GetEXIFInfo;
  if assigned(EXIF) and EXIF.IsG3Fax then
  begin
    Result := jcITUCieLAB;
    exit;
  end;}

  // No subsampling used?
  if (FSOF.MaxHorzSampling = 1) and (FSOF.MaxVertSampling = 1) then
  begin
    // No subsampling used -> Change YC method to RGB or CMYK
    case FSOF.ComponentCount of
      3: Result := jcRGB;
      4: Result := jcCMYK;
    end;
  end;

  // Use component ID's
  case FSOF.ComponentCount of
    3:
      begin
        // Possible ID strings
        if FComponentIDs = #0#1#2 then
          Result := jcYCbCr
        else
        if FComponentIDs = #1#2#3 then
          Result := jcYCbCr
        else
        if FComponentIDs = 'RGB' then
          Result := jcRGB
        else
        if FComponentIDs = 'YCc' then
          Result := jcPhotoYCC;
      end;
    4:
      begin
        // Possible ID strings
        if FComponentIDs = #1#2#3#4 then
          begin
            if FICC_PROFILEFound then
              // Note: in fact, in cases seen, this represents CMYK instead of RGBA,
              // so to decode: decode to RGBA as usual, then pretend these channels
              // are CMYK, and convert to final colour space (seen in scanners, and
              // always with ICC profile present - which has CMYK profile)
              Result := jcYCbCrK
            else
              Result := jcYCbCrA;
          end
        else
        if FComponentIDs = 'RGBA' then
          Result := jcRGBA
        else
        if FComponentIDs = 'YCcA' then
          Result := jcPhotoYCCA;
      end;
  end;
end;

function TdecJpegImage.ReadBaselineHuffmanDataUnit(AComponentIndex: Integer; ADCAC: PdecDataUnit): Cardinal;
var
  Table: PdecDHTTable;
  DCLen, DC: Integer;
  ZeroCount, ACLen, AC: Integer;
  ACCount: Integer;
  Component: PdecSOSComponent;
  ACIndex: Integer;
begin
  Table := @FDC_DHTTables[FSOS.Components[AComponentIndex].DHT_DCTableIndex];

  Result := ReadHuffman(Table, DCLen);
  if Result <> JPEG_OK then Exit;
  DC := 0;
  if DCLen > 0 then
    begin
      Result := ReadBits(DCLen, DC);
      if Result <> JPEG_OK then Exit;
    end;

  if DCLen <> 0 then
    if (1 shl (DCLen - 1)) and DC = 0 then
      DC := DC - (1 shl DCLen) + 1;
  Component := @FSOS.Components[AComponentIndex];
  DC := DC + Component.PrevDC;
  ADCAC.Values[0] := DC;
  Component.PrevDC := DC;

  Table := @FAC_DHTTables[FSOS.Components[AComponentIndex].DHT_ACTableIndex];
  ACCount := 1;
  while ACCount < 64 do
    begin
      Result := ReadHuffman(Table, ACLen);
      if Result <> JPEG_OK then Exit;
      ZeroCount := ACLen shr 4;
      ACLen := ACLen and $F;
      AC := 0;
      if ACLen > 0 then
        begin
          Result := ReadBits(ACLen, AC);
          if Result <> JPEG_OK then Exit;
        end;

      if ACLen <> 0 then
        begin
          Inc(ACCount, ZeroCount + 1);
          if ACCount > 64 then
            begin
              Result := JPEG_DATA_ERROR;
              {$IFDEF DEBUG}
              Error('Out of table: ' + IntToStr(ACCount), 0);
              {$ENDIF}
              Exit;
            end;

          if (1 shl (ACLen - 1)) and AC = 0 then
            AC := AC - (1 shl ACLen) + 1;
          ACIndex := ACCount - 1;
          ACIndex := cJpegInverseZigZag8x8[ACIndex];
          ADCAC.Values[ACIndex] := AC;
        end
      else
        begin
          if ZeroCount = $F then
            Inc(ACCount, 16)
          else
            if ZeroCount = 0 then
              ACCount := 64
            else
              begin
                Result := JPEG_DATA_ERROR;
                {$IFDEF DEBUG}
                Error('Unexpected ZeroCount value: ' + IntToStr(ZeroCount), 0);
                {$ENDIF}
                Exit;
              end;
        end;
    end;
end;

function TdecJpegImage.ReadProgressiveHuffmanDCBandFirst(AComponentIndex: Integer; ADCAC: PdecDataUnit): Cardinal;
var
  Table: PdecDHTTable;
  DCLen, DC: Integer;
  Component: PdecSOSComponent;
begin
  Table := @FDC_DHTTables[FSOS.Components[AComponentIndex].DHT_DCTableIndex];

  Result := ReadHuffman(Table, DCLen);
  if Result <> JPEG_OK then Exit;
  DC := 0;
  if DCLen > 0 then
    begin
      Result := ReadBits(DCLen, DC);
      if Result <> JPEG_OK then Exit;
    end;

  if DCLen <> 0 then
    if (1 shl (DCLen - 1)) and DC = 0 then
      DC := DC - (1 shl DCLen) + 1;
  Component := @FSOS.Components[AComponentIndex];
  DC := DC + Component.PrevDC;
  ADCAC.Values[0] := DC shl FSOS.ApproxLow;
  Component.PrevDC := DC;
end;

function TdecJpegImage.ReadProgressiveHuffmanDCBandNext(ADCAC: PdecDataUnit): Cardinal;
var
  Plus: integer;
  Value: Psmallint;
  Bit: Integer;
begin
  Plus := 1 shl FSOS.ApproxLow;
  Value := @ADCAC.Values[0];
  Result := ReadBit(Bit);
  if Result <> JPEG_OK then Exit;

  if Bit = 1 then
    if Value^ > 0 then Inc(Value^, Plus)
                  else Dec(Value^, Plus);
end;

function TdecJpegImage.ReadProgressiveHuffmanACBandFirst(var EOBRun: integer; AComponentIndex: Integer;
  ADCAC: PdecDataUnit): Cardinal;
var
  Table: PdecDHTTable;
  ZeroCount, ACLen, AC: Integer;
  ACCount: Integer;
  ACIndex: Integer;
begin
  if EOBRun > 0 then
    begin
      Dec(EOBRun);
      Result := JPEG_OK;
      Exit;
    end;

  Table := @FAC_DHTTables[FSOS.Components[AComponentIndex].DHT_ACTableIndex];
  ACCount := FSOS.SpectralStart;
  while ACCount <= FSOS.SpectralEnd do
    begin
      Result := ReadHuffman(Table, ACLen);
      if Result <> JPEG_OK then Exit;
      ZeroCount := ACLen shr 4;
      ACLen := ACLen and $F;
      AC := 0;
      if ACLen > 0 then
        begin
          Result := ReadBits(ACLen, AC);
          if Result <> JPEG_OK then Exit;
        end;

      if ACLen <> 0 then
        begin
          Inc(ACCount, ZeroCount);
          if ACCount > FSOS.SpectralEnd then
            begin
              Result := JPEG_DATA_ERROR;
              {$IFDEF DEBUG}
              Error('Out of table: ' + IntToStr(ACCount), 0);
              {$ENDIF}
              Exit;
            end;

          if (1 shl (ACLen - 1)) and AC = 0 then
            AC := AC - (1 shl ACLen) + 1;
          ACIndex := ACCount;
          ACIndex := cJpegInverseZigZag8x8[ACIndex];
          ADCAC.Values[ACIndex] := AC shl FSOS.ApproxLow;
        end
      else
        begin
          if ZeroCount = $F then
            Inc(ACCount, 15)
          else
            begin
              EOBRun := 1 shl ZeroCount;
              if ZeroCount > 0 then
                begin
                  Result := ReadBits(ZeroCount, ZeroCount);
                  if Result <> JPEG_OK then Exit;
                  Inc(EOBRun, ZeroCount);
                end;
              Dec(EOBRun);
              break;
            end;
        end;
      Inc(ACCount);
    end;

  Result := JPEG_OK;
end;

procedure TdecJpegImage.RSTFound(RST: Byte; var MCUHorzIndex, MCUVertIndex: Integer);
begin
  while RST <> FNextRSTIndex do
    begin
      Inc(FCurrentMCUIndex, FRestartInterval);
      if FNextRSTIndex = mkRST7 then FNextRSTIndex := mkRST0
                                else Inc(FNextRSTIndex);
      FDecodeError := True;
    end;
  if FNextRSTIndex = mkRST7 then FNextRSTIndex := mkRST0
                            else Inc(FNextRSTIndex);
  AfterRestart;
  MCUVertIndex := FCurrentMCUIndex div FSOS.MCUHorzCount;
  MCUHorzIndex := FCurrentMCUIndex mod FSOS.MCUHorzCount;
end;

procedure TdecJpegImage.FindNextRST(var MCUHorzIndex, MCUVertIndex: Integer);
var
  Result2: Cardinal;
  RST: Byte;
begin
  while True do
    begin
      while True do
        begin
          Result2 := ReadByte(RST);
          if Result2 <> JPEG_OK then Exit;
          if RST = $FF then Break;
        end;

      while True do
        begin
          Result2 := ReadByte(RST);
          if Result2 <> JPEG_OK then Exit;
          if RST <> $FF then Break;
        end;

      if IsRSTMarker(RST) then Break;
      {if RST = $D9 then
        begin
          Sleep(0);
          Exit;
        end;}

    end;
  RSTFound(RST, MCUHorzIndex, MCUVertIndex);
end;

function CalcIsBigImage(AWidth, AHeight: Integer): Boolean;
begin
  Result := {False and{} (AWidth > 480) and (AHeight > 480);
end;

procedure TdecJpegImage.UpdateComponentDatas(var AComponentDatas: TdecComponentDatas);
var
  ComponentIndex: Integer;
  Width: Integer;
begin
  Width := (FSOF.ImageWidth + FSOF.MCUWidth - 1) div FSOF.MCUWidth * FSOF.MCUWidth;
  for ComponentIndex := 0 to FSOF.ComponentCount - 1 do
    begin
      if not Assigned(AComponentDatas[ComponentIndex]) then
        AComponentDatas[ComponentIndex] := TdecComponentData.Create(Width, FSOF.MCUHeight)
      else
        AComponentDatas[ComponentIndex].SetSize(Width, FSOF.MCUHeight);
    end;
end;

function BytesPerScanline(PixelsPerScanline, BitsPerPixel: Longint): Longint;
const
  Alignment = 31;
begin
  if BitsPerPixel = 15 then BitsPerPixel := 16;
  Result := ((PixelsPerScanline * BitsPerPixel) + Alignment) and not Alignment;
  Result := Result div 8;
end;

procedure OutOfResources;
begin
  raise EOutOfResources.Create('OutOfResources');
end;

procedure GDIError;
var
  ErrorCode: Integer;
  Buf: array [Byte] of Char;
begin
  ErrorCode := GetLastError;
  if (ErrorCode <> 0) and (FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, nil, ErrorCode,
    LOCALE_USER_DEFAULT, Buf, sizeof(Buf), nil) <> 0) then
    raise EOutOfResources.Create(Buf)
  else
    OutOfResources;
end;

function GDICheck(Value: THandle): THandle; overload;
begin
  if Value = 0 then GDIError;
  Result := Value;
end;

function GDICheck(Value: Boolean): Boolean; overload;
begin
  if not Value then GDIError;
  Result := Value;
end;


type
  TdecPalette = packed array[Byte] of TRGBQuad;

  TMaxBitmapInfo = packed record
    bmiHeader: TBitmapInfoHeader;
    bmiColors: TdecPalette;
  end;
  PMaxBitmapInfo = ^TMaxBitmapInfo;

function CreateDIBSection_(AWidth, AHeight, ABitCount: Integer; var AData: PByte): HBITMAP;
var
  DC: HDC;
  BitmapInfo: TMaxBitmapInfo;
  PalIndex: Integer;
begin
  DC := GDICheck(GetDC(0));
  try
    ZeroMemory(@BitmapInfo, SizeOf(BitmapInfo));
    with BitmapInfo, bmiHeader do
      begin
        biSize := SizeOf(bmiHeader);
        biWidth := AWidth;
        biHeight := AHeight;
        biPlanes := 1;
        biBitCount := ABitCount;
        biCompression := BI_RGB;
        biSizeImage := BytesPerScanline(biWidth, biBitCount) * Abs(biHeight);
        if ABitCount = 8 then biClrUsed := 256
                         else biClrUsed := 0;
        biClrImportant := biClrUsed;
        for PalIndex := $00 to $FF do
          DWORD(bmiColors[PalIndex]) := (PalIndex shl 16) or (PalIndex shl 8) or PalIndex;
      end;
    Result := GDICheck(Windows.CreateDIBSection(DC, PBitmapInfo(@BitmapInfo)^, DIB_RGB_COLORS, Pointer(AData), 0, 0));
  finally
    ReleaseDC(0, DC);
  end;
end;

procedure TdecJpegImage.PrepareCreateBitmap;
begin
  {$IFDEF SUPPORT_GRAPHICS32}
  if FBitmap32Mode then
    begin
      FBitmapBPS := 32;
      FBitmapBPL := FSOF.ImageWidth * 4;

      FBitmap32 := TBitmap32.Create;
      FBitmap32.Width := FSOF.ImageWidth;
      FBitmap32.Height := FSOF.ImageHeight;
      FBitmapBits := PByte(FBitmap32.Bits);
    end
  else
  {$ENDIF}
    begin
      case FColorSpace of
        jcGray:  FBitmapBPS := 8;
        jcGrayA: FBitmapBPS := 32;
        jcRGBA:  FBitmapBPS := 32;
      else
        FBitmapBPS := 24;
      end;
      FBitmapBPL := BytesPerScanline(FSOF.ImageWidth, FBitmapBPS);

      FBitmap := CreateDIBSection_(FSOF.ImageWidth, FSOF.ImageHeight, FBitmapBPS, FBitmapBits);
      Inc(FBitmapBits, FBitmapBPL * (FSOF.ImageHeight - 1));
      FBitmapBPL := -FBitmapBPL;
    end;
end;

procedure TdecJpegImage.PostCreateBitmapEx;
var
  TotalMCUVertCount: Integer;
  MCUVertCount: Integer;
  ThreadCount: Integer;
  ThreadIndex: Integer;
  MCULineCount: Integer;
  Job: TdecJpegThreadJobRecord;
begin
  TotalMCUVertCount := (FSOF.ImageHeight + FSOF.MCUHeight - 1) div FSOF.MCUHeight;
  MCUVertCount := TotalMCUVertCount - FNextDecodeMCULine;

  if MCUVertCount = 1 then
    begin
      UpdateComponentDatas(FComponents_);
      JobDecode(FComponents_, FNextDecodeMCULine, 1);
      Inc(FNextDecodeMCULine, 1);
    end
  else
    begin
      ThreadCount := MaxThreadCount;
      if ThreadCount > MCUVertCount then
        ThreadCount := MCUVertCount;

      Job.Jpeg := Self;

      MCULineCount := Round(MCUVertCount / ThreadCount);
      if MCULineCount = 0 then
        MCULineCount := 1;

        for ThreadIndex := ThreadCount - 1 downto 0 do
          begin
            Job.FirstMCULine := FNextDecodeMCULine;
            if ThreadIndex = 0 then
              Job.MCULineCount := TotalMCUVertCount - FNextDecodeMCULine
            else
              Job.MCULineCount := MCULineCount;
            if Job.MCULineCount > TotalMCUVertCount - FNextDecodeMCULine then
              Job.MCULineCount := TotalMCUVertCount - FNextDecodeMCULine;
            AddJob(Job);
            Inc(FNextDecodeMCULine, Job.MCULineCount);
            if FNextDecodeMCULine >= TotalMCUVertCount then
              Break;
          end;
    end;

  FSignal.WaitFor;
end;

procedure TdecJpegImage.PostCreateBitmap;
var
  MCUVertCount: Integer;
  ThreadCount: Integer;
begin
  if FSOF.ImageHeight = 0 then Exit;

  PrepareCreateBitmap;
  MCUVertCount := (FSOF.ImageHeight + FSOF.MCUHeight - 1) div FSOF.MCUHeight;

  ThreadCount := MaxThreadCount;
  if ThreadCount > MCUVertCount then
    ThreadCount := MCUVertCount;

  if (ThreadCount = 1) or (MCUVertCount = 1) then
    begin
      UpdateComponentDatas(FComponents_);
      JobDecode(FComponents_, 0, MCUVertCount)
    end
  else
    begin
      FSignal := TdecJpegThreadSignal.Create;
      try
        FNextDecodeMCULine := 0;
        PostCreateBitmapEx;
        FSignal.WaitFor;
      finally
        FreeAndNil(FSignal);
      end;
    end;
end;

function TdecJpegImage.DecodeScan: Cardinal;
var
  NeedInitDCTable: Boolean;
  NeedInitACTable: Boolean;
  Table: PdecDHTTable;
  SOFIndex: Integer;
  ComponentIndex: Integer;
  DUIndex: Integer;

  EOBRun: integer;
  IsDCBand: boolean;
  IsFirst: boolean;

  TotalMCUCount: Integer;
  Component: PdecSOSComponent;
  MCUVertIndex: Integer;
  MCUHorzIndex: Integer;
  Values: PdecDataUnit;

  FindError: Boolean;
  DNLSizeH: Byte;
  DNLSizeL: Byte;
  DNLSize: Integer;
  DNLHeight: Integer;

  Job: TdecJpegThreadJobRecord;
begin
  Result := JPEG_DATA_ERROR;

  NeedInitDCTable := True;
  NeedInitACTable := True;
  IsDCBand := True; // Make compiler happy;
  IsFirst := True; // Make compiler happy;
  EOBRun := 0;

  case FSOF.Type_ of
    mkSOF0, mkSOF1:;
    mkSOF2:
      begin
        IsDCBand := FSOS.SpectralStart = 0;
        IsFirst := FSOS.ApproxHigh = 0;

        NeedInitDCTable := IsDCBand and IsFirst;
        NeedInitACTable := not IsDCBand;
      end;
  else
    Exit;
  end;

  for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
    if not FDQTTables[FSOS.Components[ComponentIndex].DQT_TableIndex].Inited then
      Exit;

  if NeedInitDCTable or NeedInitACTable then
    for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
      begin
        if NeedInitDCTable then
          begin
            Table := @FDC_DHTTables[FSOS.Components[ComponentIndex].DHT_DCTableIndex];
            if not Table.Inited then Exit;
            InitDHT(Table);
          end;
        if NeedInitACTable then
          begin
            Table := @FAC_DHTTables[FSOS.Components[ComponentIndex].DHT_ACTableIndex];
            if not Table.Inited then Exit;
            InitDHT(Table);
          end;
      end;

  for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
    begin
      SOFIndex := FSOS.Components[ComponentIndex].SOFIndex;
      if not Assigned(FMCU[SOFIndex]) then
        FMCU[SOFIndex] := TdecMCUs.Create;
      FMCU[SOFIndex].Update(FSOF, FSOS, ComponentIndex);
      FSOF.Components[SOFIndex].DQTTable := FDQTTables[FSOS.Components[ComponentIndex].DQT_TableIndex];
    end;

  InitBitReaded;
  FNextRSTIndex := mkRST0;
  TotalMCUCount := FSOS.MCUVertCount * FSOS.MCUHorzCount;
  FCurrentMCUIndex := 0;
  MCUVertIndex := 0;
  MCUHorzIndex := 0;

  while FUnknownHeight or (FCurrentMCUIndex < TotalMCUCount) do
    begin
      FindError := False;

      for ComponentIndex := 0 to FSOS.ComponentCount - 1 do
        begin
          Component := @FSOS.Components[ComponentIndex];
          for DUIndex := 0 to Component.DUHorzCount * Component.DUVertCount - 1 do
            begin
                Values := GetValues(ComponentIndex, DUIndex, MCUHorzIndex, MCUVertIndex);
                case FSOF.Type_ of
                  mkSOF0, mkSOF1:
                    begin
                      Result := ReadBaselineHuffmanDataUnit(ComponentIndex, Values);
                    end;
                  mkSOF2:
                    if IsDCBand then
                      if IsFirst then
                        Result := ReadProgressiveHuffmanDCBandFirst(ComponentIndex, Values)
                      else
                        Result := ReadProgressiveHuffmanDCBandNext(Values)
                    else
                      if IsFirst then
                        Result := ReadProgressiveHuffmanACBandFirst(EOBRun, ComponentIndex, Values)
                      else
                        Result := ReadProgressiveHuffmanACBandNext(EOBRun, ComponentIndex, Values);
                else
                  Result := JPEG_UNSUPPORTED_COMRESSION_METHOD;
                  Exit;
                end;

                case Result of
                  JPEG_OK:;
                  JPEG_UNEXPECTED_EOF,
                  JPEG_UNEXPECTED_EOI:
                    begin
                      Exit;
                    end;
                  mkRST0..mkRST7:
                    begin
                      FCurrentMCUIndex := (FCurrentMCUIndex + FRestartInterval - 1) div FRestartInterval * FRestartInterval;
                      RSTFound(Result, MCUHorzIndex, MCUVertIndex);
                      FindError := True;
                      FDecodeError := True;
                      Break;
                    end;
                  mkDNL:
                    begin
                      Result := ReadByte(DNLSizeH);
                      if Result <> JPEG_OK then Exit;
                      Result := ReadByte(DNLSizeL);
                      if Result <> JPEG_OK then Exit;
                      DNLSize := (DNLSizeH shl 8) or DNLSizeL;
                      if DNLSize <> 4 then
                        begin
                          Result := JPEG_DATA_ERROR;
                          Exit;
                        end;
                      Result := ReadByte(DNLSizeH);
                      if Result <> JPEG_OK then Exit;
                      Result := ReadByte(DNLSizeL);
                      if Result <> JPEG_OK then Exit;
                      DNLHeight := (DNLSizeH shl 8) or DNLSizeL;
                      if DNLHeight <= FSOF.ImageHeight then
                        FSOF.ImageHeight := DNLHeight;
                      FSOS.MCUVertCount := (FSOF.ImageHeight + FSOS.MCUHeight - 1) div FSOS.MCUHeight;
                      FUnknownHeight := False;
                      Result := S_OK;
                      Exit;
                    end
                else
                  if FRestartInterval <> 0 then
                    begin
                      FCurrentMCUIndex := (FCurrentMCUIndex + FRestartInterval - 1) div FRestartInterval * FRestartInterval;
                      FindNextRST(MCUHorzIndex, MCUVertIndex);
                      FindError := True;
                      FDecodeError := True;
                      Break;
                    end
                  else
                    begin
                      Exit;
                    end;
                end;

              if FindError then Break;
            end;
          if FindError then Break;
        end;

      if not FindError then
        begin
          Inc(FCurrentMCUIndex);
          Inc(MCUHorzIndex);
          if MCUHorzIndex = FSOS.MCUHorzCount then
            begin
              MCUHorzIndex := 0;
              Inc(MCUVertIndex);
            end;

          if (FRestartInterval <> 0) and (FCurrentMCUIndex < TotalMCUCount) then
            begin
              Inc(FRestartCounter);
              if FRestartCounter = FRestartInterval then
                FindNextRST(MCUHorzIndex, MCUVertIndex);
            end;
        end;

      if Assigned(FSignal) and (FCurrentMCUIndex - FNextDecodeMCULine * FSOS.MCUHorzCount >= FSOS.MCUHorzCount) then
        if FSignal.FreeThreadCount > 0 then
          begin
            Job.Jpeg := Self;
            Job.FirstMCULine := FNextDecodeMCULine;
            Job.MCULineCount := (FCurrentMCUIndex - FNextDecodeMCULine * FSOS.MCUHorzCount) div FSOS.MCUHorzCount;
            FNextDecodeMCULine := FNextDecodeMCULine + Job.MCULineCount;
            AddJob(Job);
          end;
    end;

  if FRestartInterval > 0 then
    FEnabledMarkers := FEnabledMarkers + [FNextRSTIndex];

  Result := JPEG_OK;
end;

function TdecJpegImage.ReadProgressiveHuffmanACBandNext(var EOBRun: integer; AComponentIndex: Integer;
  ADCAC: PdecDataUnit): Cardinal;
var
  Table: PdecDHTTable;
  k, kz: integer;
  RS, R, S, Plus: integer; // RS = range,category
  Bit: Integer;
begin
  Plus := 1 shl FSOS.ApproxLow;

  // Start of the spectral band
  k := FSOS.SpectralStart;

  // Not part of EOB run?
  if EOBRun = 0 then
  begin

    Table := @FAC_DHTTables[FSOS.Components[AComponentIndex].DHT_ACTableIndex];
    while k <= FSOS.SpectralEnd do
    begin
      Result := ReadHuffman(Table, RS);
      if Result <> JPEG_OK then Exit;

      R := RS shr 4;
      S := RS and $0F;

      if (S = 0) and (R < 15) then
        begin
          // EOB run
          EOBRun := 1 shl R;
          if R <> 0 then
            begin
              Result := ReadBits(R, R);
              if Result <> JPEG_OK then Exit;
              inc(EOBRun, R);
            end;
          Break;
        end;

      if S <> 0 then
        begin
          Result := ReadBit(Bit);
          if Result <> JPEG_OK then Exit;
          if Bit = 1 then S :=  Plus
                     else S := -Plus;
        end;

      // Fill values for remainder
      repeat
        kz := cJpegInverseZigZag8x8[k];
        if ADCAC.Values[kz] <> 0 then
          begin
            Result := ReadBit(Bit);
            if Result <> JPEG_OK then Exit;
            if Bit = 1 then
              begin
                if ADCAC.Values[kz] > 0 then
                  Inc(ADCAC.Values[kz], Plus)
                else
                  Dec(ADCAC.Values[kz], Plus);
              end;
          end
        else
          begin
            dec(R);
            if R < 0 then break;
          end;
        inc(k);
      until k > FSOS.SpectralEnd;

      if k <= FSOS.SpectralEnd then
      begin
        if S <> 0 then
          begin
            kz := cJpegInverseZigZag8x8[k];
            if kz > 0 then
              ADCAC.Values[kz] := S;
          end;
      end;

      // Increment range-coded index
      inc(k);

    end;//while
  end;// EOBRun = 0

  // Deal with EOBRun
  if EOBRun > 0 then
    begin
      while k <= FSOS.SpectralEnd do
        begin
          kz := cJpegInverseZigZag8x8[k];
          if ADCAC.Values[kz] <> 0 then
            begin
              Result := ReadBit(Bit);
              if Result <> JPEG_OK then Exit;
              if Bit = 1 then
                if ADCAC.Values[kz] > 0 then
                  Inc(ADCAC.Values[kz], Plus)
                else
                  Dec(ADCAC.Values[kz], Plus);
            end;
          inc(k);
        end;

      // decrement the EOB run
      dec(EOBRun);
    end;

  Result := JPEG_OK;
end;

// integer multiply with shift arithmetic right
function Multiply(A, B: integer): integer; inline;
begin
  // Delphi seems to convert the "div" here to SAR just fine (D7), so we
  // don't use ASM but plain pascal
  Result := (A * B) div cIAccConstScale;
end;

// Descale and range limit to byte domain. We shift right over
// 12 bits: 9 bits to remove precision, and 3 bits to get rid of the additional
// factor 8 introducted by the IDCT transform.
function RangeLimit(A: integer): integer; inline;
begin
  // Delphi seems to convert the "div" here to SAR just fine (D7), so we
  // don't use ASM but plain pascal
  Result := A div (1 shl cIAccRangeBits) + cCenterSample;
  if Result < 0 then
    Result := 0
  else
    if Result > cMaxSample then
      Result := cMaxSample;
end;

const
  // we use 9 bits of precision, so must multiply by 2^9
  cIFastConstBits = 9;
  cIFastRangeBits = cIFastConstBits + 3;
  cIFastConstScale = 1 shl cIFastConstBits;

procedure InverseDCTIntFast8x8(const Coef: TdecDataUnit; out Sample: TsdSampleBlock;
  const Quant: TsdIntArray64; var Wrksp: TsdIntArray64);
const
  FIX_1_082392200 = integer(Round(cIFastConstScale * 1.082392200));
  FIX_1_414213562 = integer(Round(cIFastConstScale * 1.414213562));
  FIX_1_847759065 = integer(Round(cIFastConstScale * 1.847759065));
  FIX_2_613125930 = integer(Round(cIFastConstScale * 2.613125930));

var
  i, QIdx: integer;
  dci: integer;
  dcs: byte;
  p0, p1, p2, p3, p4, p5, p6, p7: Psmallint;
  w0, w1, w2, w3, w4, w5, w6, w7: Pinteger;
  s0, s1, s2, s3, s4, s5, s6, s7: Pbyte;
  tmp0, tmp1, tmp2, tmp3, tmp4, tmp5, tmp6, tmp7: integer;
  tmp10, tmp11, tmp12, tmp13: integer;
  z5, z10, z11, z12, z13: integer;
begin
  QIdx := 0;
  // First do the columns
  p0 := @Coef.Values[ 0]; p1 := @Coef.Values[ 8]; p2 := @Coef.Values[16]; p3 := @Coef.Values[24];
  p4 := @Coef.Values[32]; p5 := @Coef.Values[40]; p6 := @Coef.Values[48]; p7 := @Coef.Values[56];
  w0 := @Wrksp[ 0]; w1 := @Wrksp[ 8]; w2 := @Wrksp[16]; w3 := @Wrksp[24];
  w4 := @Wrksp[32]; w5 := @Wrksp[40]; w6 := @Wrksp[48]; w7 := @Wrksp[56];
  for i := 0 to 7 do
  begin
    if (p1^ = 0) and (p2^ = 0) and (p3^ = 0) and (p4^ = 0) and
       (p5^ = 0) and (p6^ = 0) and (p7^ = 0) then
    begin
      dci := p0^ * Quant[QIdx];
      w0^ := dci; w1^ := dci; w2^ := dci; w3^ := dci;
      w4^ := dci; w5^ := dci; w6^ := dci; w7^ := dci;
    end else
    begin
      // Even part

      tmp0 := p0^ * Quant[QIdx     ];
      tmp1 := p2^ * Quant[QIdx + 16];
      tmp2 := p4^ * Quant[QIdx + 32];
      tmp3 := p6^ * Quant[QIdx + 48];

      tmp10 := tmp0 + tmp2;	// phase 3
      tmp11 := tmp0 - tmp2;

      tmp13 := tmp1 + tmp3;	// phases 5-3
      tmp12 := Multiply(tmp1 - tmp3, FIX_1_414213562) - tmp13; // 2*c4

      tmp0 := tmp10 + tmp13;	// phase 2
      tmp3 := tmp10 - tmp13;
      tmp1 := tmp11 + tmp12;
      tmp2 := tmp11 - tmp12;

      // Odd part

      tmp4 := p1^ * Quant[QIdx +  8];
      tmp5 := p3^ * Quant[QIdx + 24];
      tmp6 := p5^ * Quant[QIdx + 40];
      tmp7 := p7^ * Quant[QIdx + 56];

      z13 := tmp6 + tmp5;		// phase 6
      z10 := tmp6 - tmp5;
      z11 := tmp4 + tmp7;
      z12 := tmp4 - tmp7;

      tmp7 := z11 + z13;		// phase 5
      tmp11 := Multiply(z11 - z13, FIX_1_414213562); // 2*c4

      z5    := Multiply(z10 + z12, FIX_1_847759065); // 2*c2
      tmp10 := Multiply(z12, FIX_1_082392200) - z5; // 2*(c2-c6)
      tmp12 := Multiply(z10, - FIX_2_613125930) + z5; // -2*(c2+c6)

      tmp6 := tmp12 - tmp7;	// phase 2
      tmp5 := tmp11 - tmp6;
      tmp4 := tmp10 + tmp5;

      w0^ := tmp0 + tmp7;
      w7^ := tmp0 - tmp7;
      w1^ := tmp1 + tmp6;
      w6^ := tmp1 - tmp6;
      w2^ := tmp2 + tmp5;
      w5^ := tmp2 - tmp5;
      w4^ := tmp3 + tmp4;
      w3^ := tmp3 - tmp4;

    end;
    // Advance block pointers
    inc(p0); inc(p1); inc(p2); inc(p3); inc(p4); inc(p5); inc(p6); inc(p7);
    inc(w0); inc(w1); inc(w2); inc(w3); inc(w4); inc(w5); inc(w6); inc(w7);
    inc(QIdx);
  end;

  // Next do the rows
  w0 := @Wrksp[0]; w1 := @Wrksp[1]; w2 := @Wrksp[2]; w3 := @Wrksp[3];
  w4 := @Wrksp[4]; w5 := @Wrksp[5]; w6 := @Wrksp[6]; w7 := @Wrksp[7];
  s0 := @Sample[0]; s1 := @Sample[1]; s2 := @Sample[2]; s3 := @Sample[3];
  s4 := @Sample[4]; s5 := @Sample[5]; s6 := @Sample[6]; s7 := @Sample[7];
  for i := 0 to 7 do
  begin
    if (w1^ = 0) and (w2^ = 0) and (w3^ = 0) and (w4^ = 0) and
       (w5^ = 0) and (w6^ = 0) and (w7^ = 0) then
    begin
      dcs := RangeLimit(w0^);
      s0^ := dcs; s1^ := dcs; s2^ := dcs; s3^ := dcs;
      s4^ := dcs; s5^ := dcs; s6^ := dcs; s7^ := dcs;
    end else
    begin

      // Even part

      tmp10 := w0^ + w4^;
      tmp11 := w0^ - w4^;

      tmp13 := w2^ + w6^;
      tmp12 := Multiply(w2^ - w6^, FIX_1_414213562) - tmp13;

      tmp0 := tmp10 + tmp13;
      tmp3 := tmp10 - tmp13;
      tmp1 := tmp11 + tmp12;
      tmp2 := tmp11 - tmp12;

      // Odd part

      z13 := w5^ + w3^;
      z10 := w5^ - w3^;
      z11 := w1^ + w7^;
      z12 := w1^ - w7^;

      tmp7 := z11 + z13;		// phase 5
      tmp11 := Multiply(z11 - z13, FIX_1_414213562); // 2*c4

      z5    := Multiply(z10 + z12, FIX_1_847759065); // 2*c2
      tmp10 := Multiply(z12, FIX_1_082392200) - z5; // 2*(c2-c6)
      tmp12 := Multiply(z10, - FIX_2_613125930) + z5; // -2*(c2+c6)

      tmp6 := tmp12 - tmp7;	// phase 2
      tmp5 := tmp11 - tmp6;
      tmp4 := tmp10 + tmp5;

      // Final output stage: scale down by a factor of 8 and range-limit

      s0^ := RangeLimit(tmp0 + tmp7);
      s7^ := RangeLimit(tmp0 - tmp7);
      s1^ := RangeLimit(tmp1 + tmp6);
      s6^ := RangeLimit(tmp1 - tmp6);
      s2^ := RangeLimit(tmp2 + tmp5);
      s5^ := RangeLimit(tmp2 - tmp5);
      s4^ := RangeLimit(tmp3 + tmp4);
      s3^ := RangeLimit(tmp3 - tmp4);

    end;
    // Advance block pointers
    inc(s0, 8); inc(s1, 8); inc(s2, 8); inc(s3, 8);
    inc(s4, 8); inc(s5, 8); inc(s6, 8); inc(s7, 8);
    inc(w0, 8); inc(w1, 8); inc(w2, 8); inc(w3, 8);
    inc(w4, 8); inc(w5, 8); inc(w6, 8); inc(w7, 8);
  end;
end;

procedure InverseDCTIntAccurate8x8(const Coef: TdecDataUnit; out Sample: TsdSampleBlock;
  const Quant: TsdIntArray64; var Wrksp: TsdIntArray64);
const
  // Constants used in Inverse DCT
  FIX_0_298631336 = Round(cIAccConstScale * 0.298631336);
  FIX_0_390180644 = Round(cIAccConstScale * 0.390180644);
  FIX_0_541196100 = Round(cIAccConstScale * 0.541196100);
  FIX_0_765366865 = Round(cIAccConstScale * 0.765366865);
  FIX_0_899976223 = Round(cIAccConstScale * 0.899976223);
  FIX_1_175875602 = Round(cIAccConstScale * 1.175875602);
  FIX_1_501321110 = Round(cIAccConstScale * 1.501321110);
  FIX_1_847759065 = Round(cIAccConstScale * 1.847759065);
  FIX_1_961570560 = Round(cIAccConstScale * 1.961570560);
  FIX_2_053119869 = Round(cIAccConstScale * 2.053119869);
  FIX_2_562915447 = Round(cIAccConstScale * 2.562915447);
  FIX_3_072711026 = Round(cIAccConstScale * 3.072711026);
var
  i, QIdx: integer;
  dci: integer;
  dcs: byte;
  p0, p1, p2, p3, p4, p5, p6, p7: Psmallint;
  w0, w1, w2, w3, w4, w5, w6, w7: Pinteger;
  s0, s1, s2, s3, s4, s5, s6, s7: Pbyte;
  z1, z2, z3, z4, z5: integer;
  tmp0, tmp1, tmp2, tmp3, tmp10, tmp11, tmp12, tmp13: integer;
begin
  //ZeroMemory(@Wrksp, SizeOf(Wrksp));
  QIdx := 0;
  // First do the columns
  p0 := @Coef.Values[ 0]; p1 := @Coef.Values[ 8]; p2 := @Coef.Values[16]; p3 := @Coef.Values[24];
  p4 := @Coef.Values[32]; p5 := @Coef.Values[40]; p6 := @Coef.Values[48]; p7 := @Coef.Values[56];
  w0 := @Wrksp[ 0]; w1 := @Wrksp[ 8]; w2 := @Wrksp[16]; w3 := @Wrksp[24];
  w4 := @Wrksp[32]; w5 := @Wrksp[40]; w6 := @Wrksp[48]; w7 := @Wrksp[56];
  for i := 0 to 7 do
  begin
    if (p1^ = 0) and (p2^ = 0) and (p3^ = 0) and (p4^ = 0) and
       (p5^ = 0) and (p6^ = 0) and (p7^ = 0) then
    begin
      dci := p0^ * Quant[QIdx];
      w0^ := dci; w1^ := dci; w2^ := dci; w3^ := dci;
      w4^ := dci; w5^ := dci; w6^ := dci; w7^ := dci;
    end else
    begin
      // Even part

      z2 := p2^ * Quant[QIdx + 2 * 8];
      z3 := p6^ * Quant[QIdx + 6 * 8];

      z1 := MULTIPLY(z2 + z3, FIX_0_541196100);
      tmp2 := z1 + MULTIPLY(z3, - FIX_1_847759065);
      tmp3 := z1 + MULTIPLY(z2, FIX_0_765366865);

      z2 := p0^ * Quant[QIdx + 0 * 8];
      z3 := p4^ * Quant[QIdx + 4 * 8];

      tmp0 := (z2 + z3);
      tmp1 := (z2 - z3);

      tmp10 := tmp0 + tmp3;
      tmp13 := tmp0 - tmp3;
      tmp11 := tmp1 + tmp2;
      tmp12 := tmp1 - tmp2;

      // Odd part

      tmp0 := p7^ * Quant[QIdx + 7 * 8];
      tmp1 := p5^ * Quant[QIdx + 5 * 8];
      tmp2 := p3^ * Quant[QIdx + 3 * 8];
      tmp3 := p1^ * Quant[QIdx + 1 * 8];

      z1 := tmp0 + tmp3;
      z2 := tmp1 + tmp2;
      z3 := tmp0 + tmp2;
      z4 := tmp1 + tmp3;
      z5 := MULTIPLY(z3 + z4, FIX_1_175875602);

      tmp0 := MULTIPLY(tmp0, FIX_0_298631336);
      tmp1 := MULTIPLY(tmp1, FIX_2_053119869);
      tmp2 := MULTIPLY(tmp2, FIX_3_072711026);
      tmp3 := MULTIPLY(tmp3, FIX_1_501321110);
      z1 := MULTIPLY(z1, - FIX_0_899976223);
      z2 := MULTIPLY(z2, - FIX_2_562915447);
      z3 := MULTIPLY(z3, - FIX_1_961570560);
      z4 := MULTIPLY(z4, - FIX_0_390180644);

      Inc(z3, z5);
      Inc(z4, z5);

      Inc(tmp0, z1 + z3);
      Inc(tmp1, z2 + z4);
      Inc(tmp2, z2 + z3);
      Inc(tmp3, z1 + z4);

      w0^ := tmp10 + tmp3;
      w7^ := tmp10 - tmp3;
      w1^ := tmp11 + tmp2;
      w6^ := tmp11 - tmp2;
      w2^ := tmp12 + tmp1;
      w5^ := tmp12 - tmp1;
      w3^ := tmp13 + tmp0;
      w4^ := tmp13 - tmp0;

    end;
    // Advance block pointers
    inc(p0); inc(p1); inc(p2); inc(p3); inc(p4); inc(p5); inc(p6); inc(p7);
    inc(w0); inc(w1); inc(w2); inc(w3); inc(w4); inc(w5); inc(w6); inc(w7);
    inc(QIdx);
  end;

  // Next do the rows
  w0 := @Wrksp[0]; w1 := @Wrksp[1]; w2 := @Wrksp[2]; w3 := @Wrksp[3];
  w4 := @Wrksp[4]; w5 := @Wrksp[5]; w6 := @Wrksp[6]; w7 := @Wrksp[7];
  s0 := @Sample[0]; s1 := @Sample[1]; s2 := @Sample[2]; s3 := @Sample[3];
  s4 := @Sample[4]; s5 := @Sample[5]; s6 := @Sample[6]; s7 := @Sample[7];
  for i := 0 to 7 do
  begin
    if (w1^ = 0) and (w2^ = 0) and (w3^ = 0) and (w4^ = 0) and
       (w5^ = 0) and (w6^ = 0) and (w7^ = 0) then
    begin
      dcs := RangeLimit(w0^);
      s0^ := dcs; s1^ := dcs; s2^ := dcs; s3^ := dcs;
      s4^ := dcs; s5^ := dcs; s6^ := dcs; s7^ := dcs;
    end else
    begin

      // Even part:
      z2 := w2^;
      z3 := w6^;

      z1 := MULTIPLY(z2 + z3, FIX_0_541196100);
      tmp2 := z1 + MULTIPLY(z3, - FIX_1_847759065);
      tmp3 := z1 + MULTIPLY(z2, FIX_0_765366865);

      tmp0 := w0^ + w4^;
      tmp1 := w0^ - w4^;

      tmp10 := tmp0 + tmp3;
      tmp13 := tmp0 - tmp3;
      tmp11 := tmp1 + tmp2;
      tmp12 := tmp1 - tmp2;

      // Odd part:
      tmp0 := w7^;
      tmp1 := w5^;
      tmp2 := w3^;
      tmp3 := w1^;

      z1 := tmp0 + tmp3;
      z2 := tmp1 + tmp2;
      z3 := tmp0 + tmp2;
      z4 := tmp1 + tmp3;
      z5 := MULTIPLY(z3 + z4, FIX_1_175875602);

      tmp0 := MULTIPLY(tmp0, FIX_0_298631336);
      tmp1 := MULTIPLY(tmp1, FIX_2_053119869);
      tmp2 := MULTIPLY(tmp2, FIX_3_072711026);
      tmp3 := MULTIPLY(tmp3, FIX_1_501321110);
      z1 := MULTIPLY(z1, - FIX_0_899976223);
      z2 := MULTIPLY(z2, - FIX_2_562915447);
      z3 := MULTIPLY(z3, - FIX_1_961570560);
      z4 := MULTIPLY(z4, - FIX_0_390180644);

      Inc(z3, z5);
      Inc(z4, z5);

      Inc(tmp0, z1 + z3);
      Inc(tmp1, z2 + z4);
      Inc(tmp2, z2 + z3);
      Inc(tmp3, z1 + z4);

      s0^ := RangeLimit(tmp10 + tmp3);
      s7^ := RangeLimit(tmp10 - tmp3);
      s1^ := RangeLimit(tmp11 + tmp2);
      s6^ := RangeLimit(tmp11 - tmp2);
      s2^ := RangeLimit(tmp12 + tmp1);
      s5^ := RangeLimit(tmp12 - tmp1);
      s3^ := RangeLimit(tmp13 + tmp0);
      s4^ := RangeLimit(tmp13 - tmp0);

    end;
    // Advance block pointers
    inc(s0, 8); inc(s1, 8); inc(s2, 8); inc(s3, 8);
    inc(s4, 8); inc(s5, 8); inc(s6, 8); inc(s7, 8);
    inc(w0, 8); inc(w1, 8); inc(w2, 8); inc(w3, 8);
    inc(w4, 8); inc(w5, 8); inc(w6, 8); inc(w7, 8);
  end;
end;

procedure TdecJpegImage.JobIDCT(const AComponents: TdecComponentDatas; AMCULine: Integer);
var
  ComponentIndex: Integer;
  MCU: TdecMCUs;

  VertRepeatCount: Integer;
  DUHozrIndex: Integer;
  DUVertIndex: Integer;
  DUTop: Integer;
  DULeft: Integer;

  PixelHozrIndex: Integer;
  PixelVertIndex: Integer;
  PixelLeft: Integer;
  PixelTop: Integer;
  PixelIndex: Integer;

  PixelHozrRepeatIndex: Integer;
  PixelVertRepeatIndex: Integer;
  PixelX: Integer;
  PixelY: Integer;

  IntDataUnit: PdecDataUnit;
  Sample: TsdSampleBlock;
  SampleItem: Byte;
  ComponentData: TdecComponentData;
  DQT: PsdIntArray64;
  Work: TsdIntArray64;
begin
  for ComponentIndex := 0 to FSOF.ComponentCount - 1 do
    begin
      MCU := FMCU[ComponentIndex];
      if Assigned(MCU) then
        begin
          ComponentData := AComponents[ComponentIndex];
          DQT := @FSOF.Components[ComponentIndex].DQTTable.ValuesEx;

          VertRepeatCount := FSOF.MCUHeight div MCU.DUHeight;
          DUVertIndex := AMCULine * VertRepeatCount;
          DUTop := 0;
          for DUVertIndex := DUVertIndex to DUVertIndex + VertRepeatCount - 1 do
            if DUVertIndex < MCU.Height then
              begin
                DULeft := 0;
                for DUHozrIndex := 0 to MCU.Width - 1 do
                  if DUHozrIndex < MCU.Width then
                    begin
                      IntDataUnit := MCU.RealValues[DUHozrIndex, DUVertIndex];
                      InverseDCTIntAccurate8x8(IntDataUnit^, Sample, DQT^, Work);
                      //InverseDCTIntFast8x8(IntDataUnit^, Sample, DQT^, Work);

                      PixelIndex := 0;
                      PixelTop := DUTop;

                      if (MCU.PixelVertRepeatCount = 1) and (MCU.PixelHorzRepeatCount = 1) then
                        begin
                          for PixelVertIndex := 0 to 7 do
                            begin
                              PixelLeft := DULeft;
                              for PixelHozrIndex := 0 to 7 do
                                begin
                                  ComponentData[PixelLeft, PixelTop] := Sample[PixelIndex];
                                  Inc(PixelLeft);

                                  Inc(PixelIndex);
                                end;
                              Inc(PixelTop);
                            end;
                        end
                      else

                      if (MCU.PixelVertRepeatCount = 1) and (MCU.PixelHorzRepeatCount = 2) then
                        begin
                          for PixelVertIndex := 0 to 7 do
                            begin
                              PixelLeft := DULeft;
                              for PixelHozrIndex := 0 to 7 do
                                begin
                                  SampleItem := Sample[PixelIndex];

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Inc(PixelLeft);

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Inc(PixelLeft);

                                  Inc(PixelIndex);
                                end;
                              Inc(PixelTop);
                            end;
                        end
                      else

                      if (MCU.PixelVertRepeatCount = 2) and (MCU.PixelHorzRepeatCount = 1) then
                        begin
                          for PixelVertIndex := 0 to 7 do
                            begin
                              PixelLeft := DULeft;
                              for PixelHozrIndex := 0 to 7 do
                                begin
                                  SampleItem := Sample[PixelIndex];

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Inc(PixelTop);

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Dec(PixelTop);
                                  Inc(PixelLeft);

                                  Inc(PixelIndex);
                                end;
                              Inc(PixelTop, 2);
                            end;
                        end
                      else

                      if (MCU.PixelVertRepeatCount = 2) and (MCU.PixelHorzRepeatCount = 2) then
                        begin
                          for PixelVertIndex := 0 to 7 do
                            begin
                              PixelLeft := DULeft;
                              for PixelHozrIndex := 0 to 7 do
                                begin
                                  SampleItem := Sample[PixelIndex];

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Inc(PixelLeft);

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Dec(PixelLeft);
                                  Inc(PixelTop);

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Inc(PixelLeft);

                                  ComponentData[PixelLeft, PixelTop] := SampleItem;
                                  Inc(PixelLeft);
                                  Dec(PixelTop);

                                  Inc(PixelIndex);
                                end;
                              Inc(PixelTop, 2);
                            end;
                        end
                      else

                      for PixelVertIndex := 0 to 7 do
                        begin
                          PixelLeft := DULeft;
                          for PixelHozrIndex := 0 to 7 do
                            begin
                              SampleItem := Sample[PixelIndex];
                              PixelY := PixelTop;
                              for PixelVertRepeatIndex := 0 to MCU.PixelVertRepeatCount - 1 do
                                begin
                                  PixelX := PixelLeft;
                                  for PixelHozrRepeatIndex := 0 to MCU.PixelHorzRepeatCount - 1 do
                                    begin
                                      ComponentData[PixelX, PixelY] := SampleItem;
                                      Inc(PixelX);
                                    end;
                                  Inc(PixelY);
                                end;
                              Inc(PixelIndex);
                              Inc(PixelLeft, MCU.PixelHorzRepeatCount);
                            end;
                          Inc(PixelTop, MCU.PixelVertRepeatCount);
                        end;

                      Inc(DULeft, MCU.PixelHorzRepeatCount * 8);
                    end;
                Inc(DUTop, MCU.PixelVertRepeatCount * 8);
              end;
        end;
    end;
end;

function RangeLimit8(A: Integer): Integer; inline;
begin
  Result := A;
  if Result < 0 then
    Result := 0
  else
    if Result > 255 then
      Result := 255;
end;

function RangeLimitDescale(A: Integer): Integer; inline;
begin
  Result := A div FColorConvScale;
  if Result < 0 then
    Result := 0
  else
    if Result > 255 then
      Result := 255;
end;

procedure TdecJpegImage.JobGray8(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Dest^ := RangeLimit8(SourceY^); Inc(Dest);
          Inc(SourceY);
        end;
    end;
end;

procedure TdecJpegImage.JobGray24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
  V: Byte;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          V := RangeLimit8(SourceY^);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Inc(SourceY);
        end;
    end;
end;

procedure TdecJpegImage.JobGray32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
  V: Byte;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          V := RangeLimit8(SourceY^);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Dest^ := $FF; Inc(Dest);
          Inc(SourceY);
        end;
    end;
end;

procedure TdecJpegImage.JobGrayA24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
  V: Byte;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          V := RangeLimit8(SourceY^);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Inc(SourceY);
        end;
    end;
end;

procedure TdecJpegImage.JobGrayA32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY, SourceA: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
  V: Byte;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceA := AComponents[1].Data; Inc(SourceY,  AComponents[1].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          V := RangeLimit8(SourceY^);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Dest^ := V; Inc(Dest);
          Dest^ := RangeLimit8(SourceA^); Inc(Dest);
          Inc(SourceY); Inc(SourceA);
        end;
    end;
end;

procedure TdecJpegImage.JobRGB24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceR, SourceG, SourceB: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceR := AComponents[0].Data; Inc(SourceR, AComponents[0].Width * (YY - AStartLine));
      SourceG := AComponents[1].Data; Inc(SourceG, AComponents[1].Width * (YY - AStartLine));
      SourceB := AComponents[2].Data; Inc(SourceB, AComponents[2].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Dest^ := RangeLimit8(SourceB^); Inc(Dest);
          Dest^ := RangeLimit8(SourceG^); Inc(Dest);
          Dest^ := RangeLimit8(SourceR^); Inc(Dest);
          Inc(SourceB); Inc(SourceR); Inc(SourceG);
        end;
    end;
end;

procedure TdecJpegImage.JobRGB32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceR, SourceG, SourceB: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceR := AComponents[0].Data; Inc(SourceR, AComponents[0].Width * (YY - AStartLine));
      SourceG := AComponents[1].Data; Inc(SourceG, AComponents[1].Width * (YY - AStartLine));
      SourceB := AComponents[2].Data; Inc(SourceB, AComponents[2].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Dest^ := RangeLimit8(SourceB^); Inc(Dest);
          Dest^ := RangeLimit8(SourceG^); Inc(Dest);
          Dest^ := RangeLimit8(SourceR^); Inc(Dest);
          Dest^ := $FF; Inc(Dest);
          Inc(SourceB); Inc(SourceR); Inc(SourceG);
        end;
    end;
end;

procedure TdecJpegImage.JobRGBA24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceR, SourceG, SourceB: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceR := AComponents[0].Data; Inc(SourceR, AComponents[0].Width * (YY - AStartLine));
      SourceG := AComponents[1].Data; Inc(SourceG, AComponents[1].Width * (YY - AStartLine));
      SourceB := AComponents[2].Data; Inc(SourceB, AComponents[2].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Dest^ := RangeLimit8(SourceB^); Inc(Dest);
          Dest^ := RangeLimit8(SourceG^); Inc(Dest);
          Dest^ := RangeLimit8(SourceR^); Inc(Dest);
          Inc(SourceB); Inc(SourceR); Inc(SourceG);
        end;
    end;
end;

procedure TdecJpegImage.JobRGBA32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceR, SourceG, SourceB, SourceA: PdecComponentValue;
  Dest: PByte;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceR := AComponents[0].Data; Inc(SourceR, AComponents[0].Width * (YY - AStartLine));
      SourceG := AComponents[1].Data; Inc(SourceG, AComponents[1].Width * (YY - AStartLine));
      SourceB := AComponents[2].Data; Inc(SourceB, AComponents[2].Width * (YY - AStartLine));
      SourceA := AComponents[2].Data; Inc(SourceA, AComponents[3].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Dest^ := RangeLimit8(SourceB^); Inc(Dest);
          Dest^ := RangeLimit8(SourceG^); Inc(Dest);
          Dest^ := RangeLimit8(SourceR^); Inc(Dest);
          Dest^ := RangeLimit8(SourceA^); Inc(Dest);
          Inc(SourceB); Inc(SourceR); Inc(SourceG); Inc(SourceA);
        end;
    end;
end;

procedure TdecJpegImage.JobYCbCr24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY, SourceCr, SourceCb: PdecComponentValue;
  Dest: PByte;
  Yi, Ri, Gi, Bi: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceCb := AComponents[1].Data; Inc(SourceCb, AComponents[1].Width * (YY - AStartLine));
      SourceCr := AComponents[2].Data; Inc(SourceCr, AComponents[2].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Yi := FY_toRT[SourceY^];
          Ri := Yi +                      FCrtoRT[SourceCr^] + F__toR;
          Gi := Yi + FCbToGT[SourceCb^] + FCrtoGT[SourceCr^] + F__toG;
          Bi := Yi + FCbtoBT[SourceCb^]                      + F__toB;
          Dest^ := RangeLimitDescale(Bi); Inc(Dest);
          Dest^ := RangeLimitDescale(Gi); Inc(Dest);
          Dest^ := RangeLimitDescale(Ri); Inc(Dest);
          Inc(SourceY); Inc(SourceCb); Inc(SourceCr);
        end;
    end;
end;

procedure TdecJpegImage.JobYCbCr32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY, SourceCr, SourceCb: PdecComponentValue;
  Dest: PByte;
  Yi, Ri, Gi, Bi: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceCb := AComponents[1].Data; Inc(SourceCb, AComponents[1].Width * (YY - AStartLine));
      SourceCr := AComponents[2].Data; Inc(SourceCr, AComponents[2].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Yi := FY_toRT[SourceY^];
          Ri := Yi +                      FCrtoRT[SourceCr^] + F__toR;
          Gi := Yi + FCbToGT[SourceCb^] + FCrtoGT[SourceCr^] + F__toG;
          Bi := Yi + FCbtoBT[SourceCb^]                      + F__toB;
          Dest^ := RangeLimitDescale(Bi); Inc(Dest);
          Dest^ := RangeLimitDescale(Gi); Inc(Dest);
          Dest^ := RangeLimitDescale(Ri); Inc(Dest);
          Dest^ := $FF; Inc(Dest);
          Inc(SourceY); Inc(SourceCb); Inc(SourceCr);
        end;
    end;
end;

procedure TdecJpegImage.JobYCbCrA24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY, SourceCr, SourceCb: PdecComponentValue;
  Dest: PByte;
  Yi, Ri, Gi, Bi: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceCb := AComponents[1].Data; Inc(SourceCb, AComponents[1].Width * (YY - AStartLine));
      SourceCr := AComponents[2].Data; Inc(SourceCr, AComponents[2].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Yi := FY_toRT[SourceY^];
          Ri := Yi +                      FCrtoRT[SourceCr^] + F__toR;
          Gi := Yi + FCbToGT[SourceCb^] + FCrtoGT[SourceCr^] + F__toG;
          Bi := Yi + FCbtoBT[SourceCb^]                      + F__toB;
          Dest^ := RangeLimitDescale(Bi); Inc(Dest);
          Dest^ := RangeLimitDescale(Gi); Inc(Dest);
          Dest^ := RangeLimitDescale(Ri); Inc(Dest);
          Inc(SourceY); Inc(SourceCb); Inc(SourceCr);
        end;
    end;
end;

procedure TdecJpegImage.JobYCbCrA32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
var
  SourceY, SourceCr, SourceCb, SourceA: PdecComponentValue;
  Dest: PByte;
  Yi, Ri, Gi, Bi: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceCb := AComponents[1].Data; Inc(SourceCb, AComponents[1].Width * (YY - AStartLine));
      SourceCr := AComponents[2].Data; Inc(SourceCr, AComponents[2].Width * (YY - AStartLine));
      SourceA  := AComponents[3].Data; Inc(SourceA,  AComponents[3].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          Yi := FY_toRT[SourceY^];
          Ri := Yi +                      FCrtoRT[SourceCr^] + F__toR;
          Gi := Yi + FCbToGT[SourceCb^] + FCrtoGT[SourceCr^] + F__toG;
          Bi := Yi + FCbtoBT[SourceCb^]                      + F__toB;
          Dest^ := RangeLimitDescale(Bi); Inc(Dest);
          Dest^ := RangeLimitDescale(Gi); Inc(Dest);
          Dest^ := RangeLimitDescale(Ri); Inc(Dest);
          Dest^ := RangeLimit8(SourceA^); Inc(Dest);
          Inc(SourceY); Inc(SourceCb); Inc(SourceCr); Inc(SourceA^);
        end;
    end;
end;

procedure TdecJpegImage.JobCMYKAdobe24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
// When all in range [0..1]
//    CMY -> CMYK                         | CMYK -> CMY
//    Black=minimum(Cyan,Magenta,Yellow)  | Cyan=minimum(1,Cyan*(1-Black)+Black)
//    Cyan=(Cyan-Black)/(1-Black)         | Magenta=minimum(1,Magenta*(1-Black)+Black)
//    Magenta=(Magenta-Black)/(1-Black)   | Yellow=minimum(1,Yellow*(1-Black)+Black)
//    Yellow=(Yellow-Black)/(1-Black)     |
//    RGB -> CMYK                         | CMYK -> RGB
//    Black=minimum(1-Red,1-Green,1-Blue) | Red=1-minimum(1,Cyan*(1-Black)+Black)
//    Cyan=(1-Red-Black)/(1-Black)        | Green=1-minimum(1,Magenta*(1-Black)+Black)
//    Magenta=(1-Green-Black)/(1-Black)   | Blue=1-minimum(1,Yellow*(1-Black)+Black)
//    Yellow=(1-Blue-Black)/(1-Black)     |
var
  SourceC, SourceM, SourceY, SourceK: PdecComponentValue;
  Dest: PByte;
  Ck, Mk, Yk, Cu, Mu, Yu, Ku: integer;
  Ri, Gi, Bi: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceC := AComponents[0].Data; Inc(SourceC, AComponents[0].Width * (YY - AStartLine));
      SourceM := AComponents[1].Data; Inc(SourceM, AComponents[1].Width * (YY - AStartLine));
      SourceY := AComponents[2].Data; Inc(SourceY, AComponents[2].Width * (YY - AStartLine));
      SourceK := AComponents[3].Data; Inc(SourceK, AComponents[3].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          // Original colour channels are inverted: uninvert them here
          Ku := 255 - SourceK^;
          Cu := 255 - SourceC^;
          Mu := 255 - SourceM^;
          Yu := 255 - SourceY^;

          // CMYK -> CMY
          Ck := (Cu * SourceK^) div 255;
          Mk := (Mu * SourceK^) div 255;
          Yk := (Yu * SourceK^) div 255;

          //CMY -> RGB
          Ri := 255 - (Ck + Ku);
          Gi := 255 - (Mk + Ku);
          Bi := 255 - (Yk + Ku);

          Dest^ := RangeLimit8(Bi); Inc(Dest);
          Dest^ := RangeLimit8(Gi); Inc(Dest);
          Dest^ := RangeLimit8(Ri); Inc(Dest);
          Inc(SourceC); Inc(SourceM); Inc(SourceY); Inc(SourceK);
        end;
    end;
end;

procedure TdecJpegImage.JobCMYKAdobe32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
// When all in range [0..1]
//    CMY -> CMYK                         | CMYK -> CMY
//    Black=minimum(Cyan,Magenta,Yellow)  | Cyan=minimum(1,Cyan*(1-Black)+Black)
//    Cyan=(Cyan-Black)/(1-Black)         | Magenta=minimum(1,Magenta*(1-Black)+Black)
//    Magenta=(Magenta-Black)/(1-Black)   | Yellow=minimum(1,Yellow*(1-Black)+Black)
//    Yellow=(Yellow-Black)/(1-Black)     |
//    RGB -> CMYK                         | CMYK -> RGB
//    Black=minimum(1-Red,1-Green,1-Blue) | Red=1-minimum(1,Cyan*(1-Black)+Black)
//    Cyan=(1-Red-Black)/(1-Black)        | Green=1-minimum(1,Magenta*(1-Black)+Black)
//    Magenta=(1-Green-Black)/(1-Black)   | Blue=1-minimum(1,Yellow*(1-Black)+Black)
//    Yellow=(1-Blue-Black)/(1-Black)     |
var
  SourceC, SourceM, SourceY, SourceK: PdecComponentValue;
  Dest: PByte;
  Ck, Mk, Yk, Cu, Mu, Yu, Ku: integer;
  Ri, Gi, Bi: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceC := AComponents[0].Data; Inc(SourceC, AComponents[0].Width * (YY - AStartLine));
      SourceM := AComponents[1].Data; Inc(SourceM, AComponents[1].Width * (YY - AStartLine));
      SourceY := AComponents[2].Data; Inc(SourceY, AComponents[2].Width * (YY - AStartLine));
      SourceK := AComponents[3].Data; Inc(SourceK, AComponents[3].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          // Original colour channels are inverted: uninvert them here
          Ku := 255 - SourceK^;
          Cu := 255 - SourceC^;
          Mu := 255 - SourceM^;
          Yu := 255 - SourceY^;

          // CMYK -> CMY
          Ck := (Cu * SourceK^) div 255;
          Mk := (Mu * SourceK^) div 255;
          Yk := (Yu * SourceK^) div 255;

          //CMY -> RGB
          Ri := 255 - (Ck + Ku);
          Gi := 255 - (Mk + Ku);
          Bi := 255 - (Yk + Ku);

          Dest^ := RangeLimit8(Bi); Inc(Dest);
          Dest^ := RangeLimit8(Gi); Inc(Dest);
          Dest^ := RangeLimit8(Ri); Inc(Dest);
          Dest^ := $FF; Inc(Dest);
          Inc(SourceC); Inc(SourceM); Inc(SourceY); Inc(SourceK);
        end;
    end;
end;

procedure TdecJpegImage.JobYCCK24(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
// YCCK is a colorspace where the CMY part of CMYK is first converted to RGB, then
// transformed to YCbCr as usual. The K part is appended without any changes.
// To transform back, we do the YCbCr -> RGB transform, then add K
var
  SourceY, SourceCb, SourceCr, SourceK: PdecComponentValue;
  Dest: PByte;
  Yi, Cu, Mu, Yu, Ko, Kk: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceCb := AComponents[1].Data; Inc(SourceCb, AComponents[1].Width * (YY - AStartLine));
      SourceCr := AComponents[2].Data; Inc(SourceCr, AComponents[2].Width * (YY - AStartLine));
      SourceK  := AComponents[3].Data; Inc(SourceK,  AComponents[3].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          // Do the conversion in int
          Yi := FY_toRT[SourceY^];
          Ko := SourceK^; // Inverse of K (K seems to be inverted in the file)
          Kk := (255 - Ko) * FColorConvScale; // Real K, with fixed precision

          // YCbCr converted back to CMY part of CMYK
          Cu := (Yi                      + FCrtoRT[SourceCr^] + F__toR); //=original C of CMYK
          Mu := (Yi + FCbToGT[SourceCb^] + FCrtoGT[SourceCr^] + F__toG); //=original M of CMYK
          Yu := (Yi + FCbtoBT[SourceCb^]                      + F__toB); //=original Y of CMYK

          // CMYK->RGB
          Dest^ := RangeLimitDescale(255 * FColorConvScale - (Yu * Ko) div 255 - Kk); Inc(Dest);
          Dest^ := RangeLimitDescale(255 * FColorConvScale - (Mu * Ko) div 255 - Kk); Inc(Dest);
          Dest^ := RangeLimitDescale(255 * FColorConvScale - (Cu * Ko) div 255 - Kk); Inc(Dest);
          Inc(SourceY); Inc(SourceCb); Inc(SourceCr); Inc(SourceK);
        end;
    end;
end;

procedure TdecJpegImage.JobYCCK32(const AComponents: TdecComponentDatas; ABitmapBits: PByte; AStartLine, ALineCount: Integer);
// YCCK is a colorspace where the CMY part of CMYK is first converted to RGB, then
// transformed to YCbCr as usual. The K part is appended without any changes.
// To transform back, we do the YCbCr -> RGB transform, then add K
var
  SourceY, SourceCb, SourceCr, SourceK: PdecComponentValue;
  Dest: PByte;
  Yi, Cu, Mu, Yu, Ko, Kk: integer;
  XX, YY: Integer;
begin
  for YY := AStartLine to AStartLine + ALineCount - 1 do
    begin
      SourceY  := AComponents[0].Data; Inc(SourceY,  AComponents[0].Width * (YY - AStartLine));
      SourceCb := AComponents[1].Data; Inc(SourceCb, AComponents[1].Width * (YY - AStartLine));
      SourceCr := AComponents[2].Data; Inc(SourceCr, AComponents[2].Width * (YY - AStartLine));
      SourceK  := AComponents[3].Data; Inc(SourceK,  AComponents[3].Width * (YY - AStartLine));
      Dest := ABitmapBits; Inc(Dest, YY * FBitmapBPL);

      for XX := 0 to FSOF.ImageWidth - 1 do
        begin
          // Do the conversion in int
          Yi := FY_toRT[SourceY^];
          Ko := SourceK^; // Inverse of K (K seems to be inverted in the file)
          Kk := (255 - Ko) * FColorConvScale; // Real K, with fixed precision

          // YCbCr converted back to CMY part of CMYK
          Cu := (Yi                      + FCrtoRT[SourceCr^] + F__toR); //=original C of CMYK
          Mu := (Yi + FCbToGT[SourceCb^] + FCrtoGT[SourceCr^] + F__toG); //=original M of CMYK
          Yu := (Yi + FCbtoBT[SourceCb^]                      + F__toB); //=original Y of CMYK

          // CMYK->RGB
          Dest^ := RangeLimitDescale(255 * FColorConvScale - (Yu * Ko) div 255 - Kk); Inc(Dest);
          Dest^ := RangeLimitDescale(255 * FColorConvScale - (Mu * Ko) div 255 - Kk); Inc(Dest);
          Dest^ := RangeLimitDescale(255 * FColorConvScale - (Cu * Ko) div 255 - Kk); Inc(Dest);
          Dest^ := $FF; Inc(Dest);
          Inc(SourceY); Inc(SourceCb); Inc(SourceCr); Inc(SourceK);
        end;
    end;
end;

procedure TdecJpegImage.JobDecode(const AComponents: TdecComponentDatas; AMCULine, AMCULineCount: Integer);
var
  PixelLine: Integer;
  PixelHeight: Integer;
begin
  while AMCULineCount > 0 do
    begin
      JobIDCT(AComponents, AMCULine);

      PixelLine := AMCULine * FSOF.MCUHeight;
      PixelHeight := FSOF.ImageHeight - AMCULine * FSOF.MCUHeight;
      if PixelHeight > FSOF.MCUHeight then
        PixelHeight := FSOF.MCUHeight;

      case FColorSpace of
        jcGray:
          case FBitmapBPS of
            8: JobGray8(AComponents, FBitmapBits, PixelLine, PixelHeight);
            24: JobGray24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobGray32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
        jcGrayA:
          case FBitmapBPS of
            24: JobGrayA24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobGrayA32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
        jcRGB:
          case FBitmapBPS of
            24: JobRGB24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobRGB32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
        jcRGBA:
          case FBitmapBPS of
            24: JobRGBA24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobRGBA32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
        jcYCbCr, jcYCbCrA:
          case FBitmapBPS of
            24: JobYCbCr24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobYCbCr32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
        {jcYCbCrA: // Don't have a sample to test
          case FBitmapBPS of
            24: JobYCbCrA24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobYCbCrA32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;}
        jcCMYK:
          case FBitmapBPS of
            24: JobCMYKAdobe24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobCMYKAdobe32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
        jcYCCK:
          case FBitmapBPS of
            24: JobYCCK24(AComponents, FBitmapBits, PixelLine, PixelHeight);
            32: JobYCCK32(AComponents, FBitmapBits, PixelLine, PixelHeight);
          end;
      end;

      Inc(AMCULine);
      Dec(AMCULineCount);
    end;
end;

//**************************************************************************************************
// TdecComponentData
//**************************************************************************************************

constructor TdecComponentData.Create(AWidth, AHeight: Integer);
begin
  inherited Create(SizeOf(TdecComponentValue));
  Width := AWidth;
  Height := AHeight;
  ZeroData;
end;

function TdecComponentData.GetValue(AX, AY: Integer): TdecComponentValue;
{$IFDEF DEBUG}
var
  Data: PdecComponentValue;
{$ENDIF}
begin
  {$IFDEF DEBUG}
  Data := PdecComponentValue(inherited Values[AX, AY]);
  if Assigned(Data) then Result := Data^
                    else Result := 0;
  {$ELSE}
  Result := PdecComponentValue(inherited Values[AX, AY])^;
  {$ENDIF}
end;

procedure TdecComponentData.SetValue(AX, AY: Integer; AValue: TdecComponentValue);
begin
  {$IFDEF DEBUG}
  if (AX >= Width) or (AY >= Height) then
    begin
      Exit;
      MessageBox(0, 'TdecComponentData.SetValue error', nil, MB_ICONERROR);
    end;
  {$ENDIF}
  PdecComponentValue(inherited Values[AX, AY])^ := AValue;
end;

//**************************************************************************************************
// TdecJpegThreadSignal
//**************************************************************************************************

constructor TdecJpegThreadSignal.Create;
begin
  inherited Create;
  InitializeCriticalSection(FLock);
  FDoneEvent := CreateEvent(nil, True, False, nil);
  FMaxThreadCount := MaxThreadCount;
end;

destructor TdecJpegThreadSignal.Destroy;
begin
  DeleteCriticalSection(FLock);
  CloseHandle(FDoneEvent);
  inherited Destroy;
end;

procedure TdecJpegThreadSignal.WaitFor;
begin
  WaitForSingleObject(FDoneEvent, INFINITE);
end;

function TdecJpegThreadSignal.FreeThreadCount: Integer;
begin
  EnterCriticalSection(FLock);
  Result := MaxThreadCount - 1 - FValue;
  LeaveCriticalSection(FLock);
end;

procedure TdecJpegThreadSignal.IncSignal;
begin
  EnterCriticalSection(FLock);
  if FValue = 0 then
    ResetEvent(FDoneEvent);
  Inc(FValue);
  LeaveCriticalSection(FLock);
end;

procedure TdecJpegThreadSignal.DecSignal;
begin
  EnterCriticalSection(FLock);
  Dec(FValue);
  if FValue = 0 then
    SetEvent(FDoneEvent);
  LeaveCriticalSection(FLock);
end;

//**************************************************************************************************
// TdecJpegThread
//**************************************************************************************************

constructor TdecJpegThread.Create;
begin
  inherited Create;
  FWakeUp := CreateEvent(nil, True, False, nil);
end;

destructor TdecJpegThread.Destroy;
var
  ComponentIndex: Integer;
begin
  CloseHandle(FWakeUp);
  for ComponentIndex := 0 to 3 do
    FreeAndNil(FComponents[ComponentIndex]);
  inherited Destroy;
end;

procedure TdecJpegThread.Terminate;
begin
  inherited Terminate;
  SetEvent(FWakeUp);
end;

procedure TdecJpegThread.Execute;
begin
  try
    while True do
      begin
        WaitForSingleObject(FWakeUp, INFINITE);
        ResetEvent(FWakeUp);
        if Terminated then Break;

        try
          FJob.Jpeg.UpdateComponentDatas(FComponents);
          FJob.Jpeg.JobDecode(FComponents, FJob.FirstMCULine, FJob.MCULineCount);
        except
        end;

        FJob.Jpeg.FSignal.DecSignal;
        EnterCriticalSection(ThreadLock);
        try
          FreeThreads.Add(Self);
        finally
          LeaveCriticalSection(ThreadLock);
        end;
      end;
  except
  end;
end;

procedure TdecJpegThread.SetJob(AJob: TdecJpegThreadJobRecord);
begin
  FJob := AJob;
  SetEvent(FWakeUp);
end;

procedure InitThreads;
begin
  InitializeCriticalSection(ThreadLock);
  Threads := TList.Create;
  FreeThreads := TList.Create;
end;

procedure DoneThreads;
var
  ThreadIndex: Integer;
begin
  for ThreadIndex := 0 to Threads.Count - 1 do
    TdecJpegThread(Threads[ThreadIndex]).Terminate;
  for ThreadIndex := 0 to Threads.Count - 1 do
    begin
      TdecJpegThread(Threads[ThreadIndex]).WaitFor;
      TdecJpegThread(Threads[ThreadIndex]).Free;
    end;
  FreeAndNil(Threads);
  FreeAndNil(FreeThreads);
  DeleteCriticalSection(ThreadLock);
end;

initialization
  InitYCbCrTables;
  InitRGBToYCbCrTables;
  InitThreads;

finalization
  DoneThreads;

end.

