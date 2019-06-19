unit S4L.Processor.TableFormatter;

interface

type
  ITableFormatter = interface ['{C62EA95B-2548-4931-95E5-0D820860AA3E}']
    procedure Add(const line: string);
    function  Format(var lines: TArray<string>): boolean;
  end; { ITableFormatter }

function CreateTableFormatter: ITableFormatter;

implementation

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.RegularExpressions;

type
  TTableFormatter = class(TInterfacedObject, ITableFormatter)
  strict private type
    {$SCOPEDENUMS ON}
    Alignment = (Left, Centered, Right);
    {$SCOPEDENUMS OFF}
  var
    FCellMatcher: TRegEx;
    FTable      : TStringList;
  strict protected
    function  ApplyAlign(const align: Alignment; const cell: string): string; overload;
    procedure ConvertAlignmentMarkers;
    function  EndsInAlign(const cell: string; var align: Alignment): boolean;
    function  ExtractHeaderAlign(var align: TArray<Alignment>): boolean;
    procedure ProcessCells(row: integer; const align: TArray<Alignment>;
      const modifyCell: TFunc<Alignment, string, string>); overload;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Add(const line: string);
    function  Format(var lines: TArray<string>): boolean;
  end; { TTableFormatter }

{ exports }

function CreateTableFormatter: ITableFormatter;
begin
  Result := TTableFormatter.Create;
end; { CreateTableFormatter }

{ TTableFormatter }

constructor TTableFormatter.Create;
begin
  inherited;
  FTable := TStringList.Create;
  FCellMatcher := TRegEx.Create('\|\s*([^|]*?)\s*\|');
end; { TTableFormatter.Create }

destructor TTableFormatter.Destroy;
begin
  FreeAndNil(FTable);
  inherited;
end; { TTableFormatter.Destroy }

procedure TTableFormatter.Add(const line: string);
begin
  FTable.Add(line);
end; { TTableFormatter.Add }

function TTableFormatter.ApplyAlign(const align: Alignment; const cell: string): string;
begin
  case align of
    Alignment.Left:     Result := ':' + cell;
    Alignment.Centered: Result := ':' + cell + ':';
    Alignment.Right:    Result := cell + ':';
    else raise Exception.Create('TTableFormatter.ApplyAlign: Unexpected alignment type');
  end;
end; { TTableFormatter.ApplyAlign }

procedure TTableFormatter.ConvertAlignmentMarkers;
var
  align: TArray<Alignment>;
begin
  if FTable.Count < 2 then
    Exit;

  if not ExtractHeaderAlign(align) then
    Exit;

  ProcessCells(0, align,
    function (align: Alignment; cell: string): string
    begin
      Result := Copy(cell, 1, Length(cell) - 2);
    end);

  ProcessCells(1, align,
    function (align: Alignment; cell: string): string
    begin
      Result := ApplyAlign(align, cell);
    end);
end; { TTableFormatter.ConvertAlignmentMarkers }

function TTableFormatter.EndsInAlign(const cell: string; var align: Alignment): boolean;
begin
  Result := true;
  if cell.EndsWith('<-') then
    align := Alignment.Left
  else if cell.EndsWith('<>') then
    align := Alignment.Centered
  else if cell.EndsWith('->') then
    align := Alignment.Right
  else
    Result := false;
end; { TTableFormatter.EndsInAlign }

function TTableFormatter.ExtractHeaderAlign(var align: TArray<Alignment>): boolean;
begin
  var alignList := TList<Alignment>.Create;
  try
    var startPos := 1;
    var header := FTable[0];

    repeat
      var match := FCellMatcher.Match(header, startPos);
      if not match.Success then
        break; //repeat

      if (match.Groups.Count = 0) then
        Exit(false);

      var cellAlign: Alignment;
      if not EndsInAlign(match.Groups[1].Value, cellAlign) then
        Exit(false);

      alignList.Add(cellAlign);
      startPos := match.Index + match.Length - 1; //re-match last | char
    until false;

    align := alignList.ToArray;
    Result := true;
  finally FreeAndNil(alignList); end;
end; { TTableFormatter.ExtractHeaderAlign }

function TTableFormatter.Format(var lines: TArray<string>): boolean;
begin
  ConvertAlignmentMarkers;
  lines := FTable.ToStringArray;
  Result := true;
end; { TTableFormatter.Format }

procedure TTableFormatter.ProcessCells(row: integer;
  const align: TArray<Alignment>;
  const modifyCell: TFunc<Alignment, string, string>);
begin
  var startPos := 1;
  var separator := FTable[row];
  var idxAlign := 0;

  repeat
    var match := FCellMatcher.Match(separator, startPos);
    var realign := modifyCell(align[idxAlign], match.Groups[1].Value);

    Delete(separator, match.Groups[1].Index, match.Groups[1].Length);
    Insert(realign, separator, match.Groups[1].Index);

    startPos := match.Index - match.Groups[1].Length + Length(realign) + match.Length - 1; //re-match last | char
    Inc(idxAlign);
  until idxAlign > High(align);

  FTable[row] := separator;
end; { TTableFormatter.ProcessCells }

end.
