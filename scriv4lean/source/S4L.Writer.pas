unit S4L.Writer;

interface

uses
  System.Classes,
  S4L.Errors;

type
  IBookmark = interface ['{32F5EFD1-E580-48F5-9B51-B0C374D15428}']
    function  AllLines: TArray<string>;
    procedure Replace(const oldPattern, newPattern: string);
    procedure ReplaceAll(const lines: TArray<string>);
    procedure TrimEnd(const value: string);
    procedure TrimStart(const value: string);
    procedure WriteLine(const line: string); overload;
    procedure WriteLine(const lines: TArray<string>); overload;
  end; { IBookmark }

  TLineProcessor = reference to function (const line: string): string;
  TTwoLineProcessor = reference to procedure (var line, nextLine: string);

  IWriter = interface(IErrorBase) ['{271773F4-217C-4A04-B051-BC7B4046379A}']
    function  GetAppendNextLine: boolean;
    procedure SetAppendNextLine(const value: boolean);
  //
    procedure AppendToLastLine(const line: string);
    function  CreateBookmark: IBookmark;
    procedure Flush;
    procedure ForEachLine(processor: TLineProcessor); overload;
    procedure ForEachLine(processor: TTwoLineProcessor); overload;
    function  MakeSegments(const startMarker, endMarker: string;
      removeMarkers: boolean): TArray<IBookmark>;
    procedure MergeWithNext(const bookmark: IBookmark);
    procedure MergeWithPrevious(const bookmark: IBookmark);
    procedure WriteLine(const line: string); overload;
    procedure WriteLine(const lines: TArray<string>); overload;
    property AppendNextLine: boolean read GetAppendNextLine write SetAppendNextLine;
  end; { IWriter }

function CreateWriter(const fileName: string; var errMsg: string): IWriter;

implementation

uses
  System.SysUtils, System.StrUtils, System.Generics.Collections,
  S4L.Platform;

type
  TBookmark = class(TInterfacedObject, IBookmark)
  strict private
    FWriter: TStringList;
  public
    constructor Create(writer: TStringList);
    function  AllLines: TArray<string>;
    procedure Replace(const oldPattern, newPattern: string);
    procedure ReplaceAll(const lines: TArray<string>);
    procedure TrimEnd(const value: string);
    procedure TrimStart(const value: string);
    procedure WriteLine(const line: string); overload;
    procedure WriteLine(const lines: TArray<string>); overload;
    property Writer: TStringList read FWriter;
  end; { TBookmark }

  TWriter = class(TErrorBase, IWriter)
  strict private type
    TPosition = record
      Segment: integer;
      Line   : integer;
      Char   : integer;
      class function First: TPosition; static;
      class function Invalid: TPosition; static;
      function  IsValid: boolean;
      function  NextChar: TPosition;
      function  NextLine: TPosition;
      function  NextSegment: TPosition;
    end; { TPosition }

    TInterval = record
      StartPos: TPosition;
      EndPos  : TPosition;
      constructor Create(const AStartPos, AEndPos: TPosition);
    end; { TInterval }
  var
    FActiveContent : TStringList;
    FAppendNextLine: boolean;
    FContent       : TObjectList<TStringList>;
    FStreamWriter  : TStreamWriter;
  strict protected
    procedure AppendWriter;
    function  ExtractFromStart(const position: TPosition): TArray<string>;
    function  ExtractInterval(const interval: TInterval): IBookmark;
    function  ExtractToEnd(const position: TPosition): TArray<string>;
    function  Find(const value: string; const startPos: TPosition): TPosition;
    function  FindInSegment(const value: string; const startPos: TPosition): TPosition;
    function  GetAppendNextLine: boolean;
    function  IndexOf(const bookmark: IBookmark): integer;
    procedure Reverse(bookmarks: TList<IBookmark>);
    procedure SetAppendNextLine(const value: boolean);
    function  SplitSegment(const position: TPosition): IBookmark;
  public
    constructor Create(streamWriter: TStreamWriter);
    destructor  Destroy; override;
    procedure AppendToLastLine(const line: string);
    function  CreateBookmark: IBookmark;
    procedure Flush;
    procedure ForEachLine(processor: TLineProcessor); overload;
    procedure ForEachLine(processor: TTwoLineProcessor); overload;
    function  MakeSegments(const startMarker, endMarker: string;
      removeMarkers: boolean): TArray<IBookmark>;
    procedure MergeWithNext(const bookmark: IBookmark);
    procedure MergeWithPrevious(const bookmark: IBookmark);
    procedure WriteLine(const line: string); overload;
    procedure WriteLine(const lines: TArray<string>); overload;
    property AppendNextLine: boolean read GetAppendNextLine write SetAppendNextLine;
  end; { TWriter }

{ exports }

function CreateWriter(const fileName: string; var errMsg: string): IWriter;
begin
  try
    Result := TWriter.Create(TStreamWriter.Create(fileName));
  except
    on E: EFCreateError do begin // comes from TStreamWriter.Create
      errMsg := Format('Failed to create file %s: %s', [fileName, E.Message]);
      Result := nil;
    end;
  end;
end; { CreateWriter }

{ TBookmark }

constructor TBookmark.Create(writer: TStringList);
begin
  inherited Create;
  FWriter := writer;
end; { TBookmark.Create }

function TBookmark.AllLines: TArray<string>;
begin
  Result := FWriter.ToStringArray;
end; { TBookmark.AllLines }

procedure TBookmark.Replace(const oldPattern, newPattern: string);
begin
  for var i := 0 to Writer.Count - 1 do
    Writer[i] := StringReplace(Writer[i], oldPattern, newPattern, [rfReplaceAll]);
end; { TBookmark.Replace }

procedure TBookmark.ReplaceAll(const lines: TArray<string>);
begin
  FWriter.Clear;
  FWriter.AddStrings(lines);
end; { TBookmark.ReplaceAll }

procedure TBookmark.TrimEnd(const value: string);
begin
  if (FWriter.Count > 0) and FWriter[FWriter.Count - 1].EndsWith(value) then
    FWriter[FWriter.Count - 1] := Copy(FWriter[FWriter.Count - 1], 1, Length(FWriter[FWriter.Count - 1]) - Length(value));
end; { TBookmark.TrimEnd }

procedure TBookmark.TrimStart(const value: string);
begin
  if (FWriter.Count > 0) and FWriter[0].StartsWith(value) then
    FWriter[0] := Copy(FWriter[0], Length(value) + 1);
end; { TBookmark.TrimStart }

procedure TBookmark.WriteLine(const line: string);
begin
  Writer.Add(line);
end; { TBookmark.WriteLine }

procedure TBookmark.WriteLine(const lines: TArray<string>);
begin
  for var s in lines do
    WriteLine(s);
end; { TBookmark.WriteLine }

{ TWriter }

constructor TWriter.Create(streamWriter: TStreamWriter);
begin
  inherited Create;
  FStreamWriter := streamWriter;
  FContent := TObjectList<TStringList>.Create;
  AppendWriter;
end; { TWriter.Create }

destructor TWriter.Destroy;
begin
  Flush;
  FreeAndNil(FContent);
  FreeAndNil(FStreamWriter);
  inherited;
end; { TWriter.Destroy }

procedure TWriter.AppendToLastLine(const line: string);
begin
  if FActiveContent.Count > 0 then
    FActiveContent[FActiveContent.Count - 1] := FActiveContent[FActiveContent.Count - 1] + line
  else
    WriteLine(line);
end; { TWriter.AppendToLastLine }

procedure TWriter.AppendWriter;
begin
  FActiveContent := TStringList.Create;
  FContent.Add(FActiveContent);
end; { TWriter.AppendWriter }

function TWriter.CreateBookmark: IBookmark;
begin
  AppendWriter;
  Result := TBookmark.Create(FActiveContent);
  AppendWriter;
end; { TWriter.CreateBookmark }

function TWriter.ExtractFromStart(const position: TPosition): TArray<string>;
begin
  var segment := FContent[position.Segment];
  var data := TList<string>.Create;

  for var i := 0 to position.Line - 1 do begin
    data.Add(segment[0]);
    segment.Delete(0);
  end;

  data.Add(Copy(segment[0], 1, position.Char));
  segment[0] := Copy(segment[0], position.Char + 1);

  Result := data.ToArray;
end; { TWriter.ExtractFromStart }

function TWriter.ExtractInterval(const interval: TInterval): IBookmark;
begin
  var startPos := interval.StartPos;
  var endPos:= interval.EndPos;

  Result := SplitSegment(endPos.NextChar);

  while startPos.Segment < endPos.Segment do begin
    Result.WriteLine(ExtractToEnd(startPos));
    startPos := startPos.NextSegment;
  end;

  Result.WriteLine(ExtractToEnd(startPos));
end; { TWriter.ExtractInterval }

function TWriter.ExtractToEnd(const position: TPosition): TArray<string>;
begin
  var segment := FContent[position.Segment];
  var data := TList<string>.Create;

  if position.Char <= Length(segment[position.Line]) then begin
    data.Add(Copy(segment[position.Line], position.Char));
    segment[position.Line] := Copy(segment[position.Line], 1, position.Char - 1);
  end;

  while (position.Line + 1) < segment.Count do begin
    data.Add(segment[position.Line + 1]);
    segment.Delete(position.Line + 1);
  end;

  Result := data.ToArray;
end; { TWriter.ExtractToEnd }

function TWriter.Find(const value: string; const startPos: TPosition): TPosition;
begin
  Result := TPosition.Invalid;

  if not startPos.IsValid then
    Exit;

  var searchPos := startPos;
  while searchPos.Segment < FContent.Count do begin
    Result := FindInSegment(value, searchPos);
    if Result.IsValid then
      Exit;
    searchPos := searchPos.NextSegment;
  end;
end; { TWriter.Find }

function TWriter.FindInSegment(const value: string; const startPos: TPosition): TPosition;
begin
  Result := startPos;
  var segment := FContent[Result.Segment];
  while Result.Line < segment.Count do begin
    var pos := PosEx(value, segment[Result.Line], Result.Char);
    if pos > 0 then begin
      Result.Char := pos;
      Exit;
    end;
    Result := Result.NextLine;
  end;
  Result := TPosition.Invalid;
end; { TWriter.FindInSegment }

procedure TWriter.Flush;
begin
  for var sl in FContent do
    for var line in sl do
      FStreamWriter.WriteLine(line);
  FContent.Clear;
end; { TWriter.Flush }

procedure TWriter.ForEachLine(processor: TLineProcessor);
begin
  for var sl in FContent do
    for var i := 0 to sl.Count - 1 do
      sl[i] := StringReplace(processor(sl[i]), #13, TPlatform.NewLineDelim, [rfReplaceAll]);
end; { TWriter.ForEachLine }

procedure TWriter.ForEachLine(processor: TTwoLineProcessor);
var
  line    : string;
  nextLine: string;
begin
  for var iSl := 0 to FContent.Count - 1 do begin
    var sl := FContent[iSl];
    var i := 0;
    while i < (sl.Count - 1) do begin
      line := sl[i];
      nextLine := sl[i+1];
      processor(line, nextLine);
      if (sl[i] <> '') and (line = '') then
        sl.Delete(i)
      else begin
        sl[i] := line;
        sl[i+1] := nextLine;
        Inc(i);
      end;
    end;
    if (sl.Count > 0) and (iSl < (FContent.Count - 1)) and (FContent[iSl + 1].Count > 0) then begin
      i := sl.Count - 1;
      line := sl[i];
      nextLine := FContent[iSl + 1][0];
      processor(line, nextLine);
      if (sl[i] <> '') and (line = '') then
        sl.Delete(i);
    end;
  end;
end; { TWriter.ForEachLine }

function TWriter.GetAppendNextLine: boolean;
begin
  Result := FAppendNextLine;
end; { TWriter.GetAppendNextLine }

function TWriter.IndexOf(const bookmark: IBookmark): integer;
begin
  for Result := 0 to FContent.Count - 1 do
    if FContent[Result] = TBookmark(bookmark).Writer then
      Exit;

  Result := -1;
end; { TWriter.IndexOf }

function TWriter.MakeSegments(const startMarker, endMarker: string;
  removeMarkers: boolean): TArray<IBookmark>;
begin
  var markers := TStack<TInterval>.Create;

  var lastPos := TPosition.First;
  repeat
    var posStart := Find(startMarker, lastPos);
    if not posStart.IsValid then
      break; //repeat
    var posEnd := Find(endMarker, posStart);
    if not posEnd.IsValid then
      break; //repeat
    posEnd.Char := posEnd.Char + Length(endMarker) - 1;
    markers.Push(TInterval.Create(posStart, posEnd));
    lastPos := posEnd;
  until false;

  var bookmarks := TList<IBookmark>.Create;
  while markers.Count > 0 do begin
    var bookmark := ExtractInterval(markers.Pop);
    if removeMarkers then begin
      bookmark.TrimStart(startMarker);
      bookmark.TrimEnd(endMarker);
    end;
    bookmarks.Add(bookmark);
  end;
  Reverse(bookmarks);

  Result := bookmarks.ToArray;
end; { TWriter.MakeSegments }

procedure TWriter.MergeWithNext(const bookmark: IBookmark);
begin
  var idxBookmark := IndexOf(bookmark);
  Assert(idxBookmark >= 0);

  if idxBookmark < (FContent.Count - 1) then begin
    var sl1 := FContent[idxBookmark];
    var sl2 := FContent[idxBookmark + 1];
    if (sl1.Count > 0) and (sl2.Count > 0) then begin
      sl1[sl1.Count - 1] := sl1[sl1.Count - 1] + sl2[0];
      sl2.Delete(0);
    end;
  end;
end; { TWriter.MergeWithNext }

procedure TWriter.MergeWithPrevious(const bookmark: IBookmark);
begin
  var idxBookmark := IndexOf(bookmark);
  Assert(idxBookmark >= 0);

  if idxBookmark > 0 then begin
    var sl1 := FContent[idxBookmark - 1];
    var sl2 := FContent[idxBookmark];
    if (sl1.Count > 0) and (sl2.Count > 0) then begin
      sl2[0] := sl1[sl1.Count - 1] + sl2[0];
      sl1.Delete(sl1.Count - 1);
    end;
  end;
end; { TWriter.MergeWithPrevious }

procedure TWriter.Reverse(bookmarks: TList<IBookmark>);
begin
  for var i := 0 to bookmarks.Count div 2 - 1 do begin
    var tmp := bookmarks[i];
    bookmarks[i] := bookmarks[bookmarks.Count - 1 - i];
    bookmarks[bookmarks.Count - 1 - i] := tmp;
  end;
end; { TWriter.Reverse }

procedure TWriter.SetAppendNextLine(const value: boolean);
begin
  FAppendNextLine := value;
end; { TWriter.SetAppendNextLine }

function TWriter.SplitSegment(const position: TPosition): IBookmark;
begin
  var list1 := TStringList.Create;
  Result := TBookmark.Create(list1);
  FContent.Insert(position.Segment + 1, list1);

  var list2 := TStringList.Create;
  var bookmark := TBookmark.Create(list2);
  FContent.Insert(position.Segment + 2, list2);

  bookmark.WriteLine(ExtractToEnd(position));

  FActiveContent := FContent.Last;
end; { TWriter.SplitSegment }

procedure TWriter.WriteLine(const line: string);
begin
  if not FAppendNextLine then
    FActiveContent.Add(line)
  else begin
    FAppendNextLine := false;
    AppendToLastLine(line);
  end;
end; { TWriter.WriteLine }

procedure TWriter.WriteLine(const lines: TArray<string>);
begin
  for var s in lines do
    WriteLine(s);
end; { TWriter.WriteLine }

{ TWriter.TPosition }

class function TWriter.TPosition.First: TPosition;
begin
  Result.Segment := 0;
  Result.Line := 0;
  Result.Char := 1;
end; { TPosition.First }

class function TWriter.TPosition.Invalid: TPosition;
begin
  Result.Segment := -1;
end; { TPosition.Invalid }

function TWriter.TPosition.IsValid: boolean;
begin
  Result := Segment >= 0;
end; { TPosition.IsValid }

function TWriter.TPosition.NextChar: TPosition;
begin
  Result.Segment := Segment;
  Result.Line := Line;
  Result.Char := Char + 1;
end; { TPosition.NextChar }

function TWriter.TPosition.NextLine: TPosition;
begin
  Result.Segment := Segment;
  Result.Line := Line + 1;
  Result.Char := 1;
end; { TPosition.NextLine }

function TWriter.TPosition.NextSegment: TPosition;
begin
  Result.Segment := Segment + 1;
  Result.Line := 0;
  Result.Char := 1;
end; { TPosition.NextSegment }

{ TWriter.TInterval }

constructor TWriter.TInterval.Create(const AStartPos, AEndPos: TPosition);
begin
  StartPos := AStartPos;
  EndPos := AEndPos;
end; { TInterval.Create }

end.
