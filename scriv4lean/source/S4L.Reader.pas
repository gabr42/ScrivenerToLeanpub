unit S4L.Reader;

interface

uses
  System.Classes,
  S4L.Errors, S4L.Metadata;

type
  IReader = interface(IErrorBase) ['{F0AC792C-6209-4245-878C-7D43430BC0DB}']
    function  GetCurrentLine: integer;
  //
    function  GetAll: TArray<string>;
    function  GetLine(var line: string): boolean;
    procedure PushBack(const line: string);
    function  ReadMetadata(const metadata: IMetadata): boolean;
    property CurrentLine: integer read GetCurrentLine;
  end; { IReader }

function CreateReader(const fileName: string; var errMsg: string;
  retryCount: integer = 1; retryDelay_ms: integer = 100): IReader;

implementation

uses
  System.SysUtils, System.Generics.Collections;

type
  TReader = class(TErrorBase, IReader)
  strict private
    FCurrentLine : integer;
    FPushBack    : TList<string>;
    FStreamReader: TStreamReader;
  strict protected
    function  GetCurrentLine: integer;
  public
    constructor Create(streamReader: TStreamReader);
    destructor  Destroy; override;
    function  GetAll: TArray<string>;
    function  GetLine(var line: string): boolean;
    procedure PushBack(const line: string);
    function  ReadMetadata(const metadata: IMetadata): boolean;
    property CurrentLine: integer read GetCurrentLine;
  end; { TReader }

{ exports }

function CreateReader(const fileName: string; var errMsg: string;
  retryCount: integer = 1; retryDelay_ms: integer = 100): IReader;

var
  streamReader: TStreamReader;

  function CreateStreamReader: boolean;
  begin
    try
      streamReader := TStreamReader.Create(fileName);
      Result := true;
    except
      on EFOpenError do
        Result := false;
    end;
  end; { CreateStreamReader }

begin
  streamReader := nil;
  try
    for var retry := 1 to retryCount - 1 do begin
      if CreateStreamReader then
        break; //for
      Sleep(retryDelay_ms);
    end;
    if not assigned(streamReader) then
      streamReader := TStreamReader.Create(fileName);
    Result := TReader.Create(streamReader);
  except
    on E: EFOpenError do begin // comes from TStreamReader.Create
      errMsg := Format('Failed to open file %s: %s', [fileName, E.Message]);
      Result := nil;
    end;
  end;
end; { CreateReader }

{ TReader }

constructor TReader.Create(streamReader: TStreamReader);
begin
  inherited Create;
  FStreamReader := streamReader;
  FPushBack := TList<string>.Create;
end; { TReader.Create }

destructor TReader.Destroy;
begin
  FreeAndNil(FPushBack);
  FreeAndNil(FStreamReader);
  inherited;
end; { TReader.Destroy }

function TReader.GetAll: TArray<string>;
var
  content: TStringList;
  line   : string;
begin
  content := TStringList.Create;
  try
    while GetLine(line) do
      content.Add(line);
    Result := content.ToStringArray;
  finally FreeAndNil(content); end;
end; { TReader.GetAll }

function TReader.GetCurrentLine: integer;
begin
  Result := FCurrentLine;
end; { TReader.GetCurrentLine }

function TReader.GetLine(var line: string): boolean;
begin
  Inc(FCurrentLine);

  if FPushBack.Count > 0 then begin
    line := FPushBack.Last;
    FPushBack.Delete(FPushBack.Count - 1);
    Result := true;
  end
  else begin
    Result := not FStreamReader.EndOfStream;
    if Result then
      line := FStreamReader.ReadLine
    else
      SetError('EOF');
  end;

  if Result then begin
    var p := Pos(#$2028, line);
    if p > 0 then begin
      FPushBack.Add(Copy(line, p+1));
      line := Copy(line, 1, p-1);
    end;
  end;
end; { TReader.GetLine }

procedure TReader.PushBack(const line: string);
begin
  FPushBack.Add(line);
  Dec(FCurrentLine);
end; { TReader.PushBack }

function TReader.ReadMetadata(const metadata: IMetadata): boolean; //FI:W521
var
  line: string;
begin
  metadata.Clear;
  repeat
    if not GetLine(line) then
      Exit(SetError('End of file detected while reading metadata'));
    if line = '' then
      Exit(true);

    // if an image is placed as a first item in chapter/section, metadata
    // is not followed by an empty line; same with a bullet list
    if line.StartsWith('![') or line.StartsWith('*') then begin
      PushBack(line);
      Exit(true);
    end;

    var posColon := Pos(':', line);
    if posColon = 0 then
      Exit(true); // empty line after the metadata is sometimes missing
    metadata[TrimRight(Copy(line, 1, posColon - 1))] := TrimLeft(Copy(line, posColon + 1));
  until false;
end; { TReader.ReadMetadata }

end.
