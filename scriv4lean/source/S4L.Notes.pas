unit S4L.Notes;

interface

uses
  S4L.Format;

type
  INote = interface ['{E7BDF834-B36B-4999-8F58-952BAAEC3A18}']
    procedure Append(const line: string);
    function  Description: TArray<string>;
    function  Marker: string;
  end; { INote }

  INotes = interface ['{D4B843A6-6605-413D-945E-38A02353C763}']
    function All: TArray<INote>;
    function StartEndnote: INote;
    function StartFootnote: INote;
  end; { INotes }

function  CreateNotes(const format: IFormat): INotes;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TNote = class(TInterfacedObject, INote)
  strict private
    FContent: TStringList;
    FFormat : IFormat;
    FName   : string;
  public
    constructor Create(const format: IFormat; const name: string);
    destructor  Destroy; override;
    procedure Append(const line: string);
    function  Description: TArray<string>;
    function  Marker: string; virtual; abstract;
    property Format: IFormat read FFormat;
    property Name: string read FName;
  end; { TNote }

  TFootnote = class(TNote)
  public
    function  Marker: string; override;
  end; { TFootnote }

  TEndnote = class(TNote)
  public
    function  Marker: string; override;
  end; { TEndnote }

  TNotes = class(TInterfacedObject, INotes)
  strict private
    FCounter: integer;
    FFormat : IFormat;
    FNotes  : TList<INote>;
  public
    constructor Create(const format: IFormat);
    destructor  Destroy; override;
    function All: TArray<INote>;
    function StartEndnote: INote;
    function StartFootnote: INote;
  end; { TNotes }

{ exports }

function CreateNotes(const format: IFormat): INotes;
begin
  Result := TNotes.Create(format);
end; { CreateNotes }

{ TNote }

constructor TNote.Create(const format: IFormat; const name: string);
begin
  inherited Create;
  FFormat := format;
  FName := name;
  FContent := TStringList.Create;
end; { TNote.Create }

destructor TNote.Destroy;
begin
  FreeAndNil(FContent);
  inherited;
end; { TNote.Destroy }

procedure TNote.Append(const line: string);
begin
  FContent.Add(line);
end; { TNote.Append }

function TNote.Description: TArray<string>;
begin
  Result := FContent.ToStringArray;
  if Length(Result) > 0 then
    Result[0] := Marker + ': ' + Result[0];
end; { TNote.Description }

{ TFootnote }

function TFootnote.Marker: string;
begin
  Result := Format.Footnote(Name);
end; { TFootnote.Marker }

{ TEndnote }

function TEndnote.Marker: string;
begin
  Result := Format.Endnote(Name);
end; { TEndnote.Marker }

{ TNotes }

constructor TNotes.Create(const format: IFormat);
begin
  inherited Create;
  FFormat := format;
  FNotes := TList<INote>.Create;
end; { TNotes.Create }

destructor TNotes.Destroy;
begin
  FreeAndNil(FNotes);
  inherited;
end; { TNotes.Destroy }

function TNotes.All: TArray<INote>;
begin
  Result := FNotes.ToArray;
end; { TNotes.All }

function TNotes.StartEndnote: INote;
begin
  Inc(FCounter);
  Result := TEndnote.Create(FFormat, 'scriv4lean-endnote-' + FCounter.ToString);
  FNotes.Add(Result);
end; { TNotes.StartEndnote }

function TNotes.StartFootnote: INote;
begin
  Inc(FCounter);
  Result := TFootnote.Create(FFormat, 'scriv4lean-footnote-' + FCounter.ToString);
  FNotes.Add(Result);
end; { TNotes.StartFootnote }

end.
