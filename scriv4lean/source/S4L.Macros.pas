unit S4L.Macros;

interface

uses
  S4L.Errors, S4L.Writer, S4L.Global;

type
  IMacros = interface(IErrorBase) ['{DEA6A57B-A177-4ADD-9A8D-36B0362B3095}']
    procedure ApplyTo(const writer: IWriter; var problems: TArray<string>); overload;
    function  ApplyTo(const lines: TArray<string>; var problems: TArray<string>): TArray<string>; overload;
    function  Process(var line: string): boolean;
    procedure RecordCaptionAnchor(const anchor: string);
    procedure RecordSpecialAnchor(const anchor: string);
    procedure SetChapterNumber(number: integer);
    procedure SetChapterName(const name: string);
    procedure SetSectionName(const name: string);
  end; { IMacros }

function CreateMacros(const global: IGlobal): IMacros;

implementation

uses
  System.SysUtils, System.Math, System.Classes, System.RegularExpressions,
  System.Generics.Defaults, System.Generics.Collections,
  S4L.Reader;

type
  TMacros = class(TErrorBase, IMacros)
  strict private const
    CThisChapter = '_chapter';
    CThisSection = '_section';
  type
    TDispatchFunc = reference to function (const macro, params: string; var replacement: string): boolean;
  var
    FChapterCounters : TDictionary<string, integer>;
    FCounters        : TDictionary<string, integer>;
    FChapterName     : string;
    FChapterNumber   : integer;
    FDispatcher      : array ['A'..'z'] of TDispatchFunc;
    FGlobal          : IGlobal;
    FIncludeMatcher  : TRegEx;
    FLastAutoNumberID: string;
    FLineNumber      : integer;
    FMacroMatcher    : TRegEx;
    FProblems        : TList<string>;
    FReferenceMatcher: TRegEx;
    FReplacements    : TDictionary<string, string>;
    FSectionName     : string;
  strict protected
    procedure AddProblem(const problemMsg: string);
    function  AnchorMacro(const macro, params: string; var replacement: string): boolean;
    function  AnchorLinkMacro(const macro, params: string; var replacement: string): boolean;
    function  DefineMacro(const macro, params: string; var replacement: string): boolean;
    function  IncludeFiles(const line: string): string;
    function  IncludeMacro(const macro, params: string; var replacement: string): boolean;
    function  NumberChapterMacro(const macro, params: string; var replacement: string): boolean;
    function  NumberMacro(const macro, params: string; var replacement: string): boolean;
    function  ReferenceMacro(const macro, params: string; var replacement: string): boolean;
    function  ReferenceNameMacro(const macro, params: string; var replacement: string): boolean;
    function  ReplaceReferences(const line: string): string;
  public
    constructor Create(const global: IGlobal);
    destructor  Destroy; override;
    procedure ApplyTo(const writer: IWriter; var problems: TArray<string>); overload;
    function  ApplyTo(const lines: TArray<string>;
      var problems: TArray<string>): TArray<string>; overload;
    function  Process(var line: string): boolean;
    procedure RecordCaptionAnchor(const anchor: string);
    procedure RecordSpecialAnchor(const anchor: string);
    procedure SetChapterNumber(number: integer);
    procedure SetChapterName(const name: string);
    procedure SetSectionName(const name: string);
  end; { TMacros }

{ externals }

function CreateMacros(const global: IGlobal): IMacros;
begin
  Result := TMacros.Create(global);
end; { CreateMacros }

{ TMacros }

constructor TMacros.Create(const global: IGlobal);
begin
  inherited Create;
  FGlobal := global;
  FMacroMatcher := TRegEx.Create(
    '<@([a-zA-Z]):'                          +
    '([^>"“”]*'                              +
     '|'                                     +
     '[^>"“”]*=["“”]([^\"“”]|\\["“”])*["“”]' +
    ')>');
  FReferenceMatcher := TRegEx.Create('<@r:([^>]*)>');
  FIncludeMatcher := TRegEx.Create('<@I:([^>]*)>');
  FDispatcher['a'] := AnchorMacro;
  FDispatcher['A'] := AnchorLinkMacro;
  FDispatcher['d'] := DefineMacro;
  FDispatcher['n'] := NumberMacro;
  FDispatcher['N'] := NumberChapterMacro;
  FDispatcher['r'] := ReferenceMacro;
  FDispatcher['R'] := ReferenceNameMacro;
  FDispatcher['I'] := IncludeMacro;
  FChapterCounters := TDictionary<string, integer>.Create(
    TOrdinalIStringComparer(TIStringComparer.Ordinal));
  FCounters := TDictionary<string, integer>.Create(
    TOrdinalIStringComparer(TIStringComparer.Ordinal));
  FReplacements := TDictionary<string, string>.Create(
    TOrdinalIStringComparer(TIStringComparer.Ordinal));
end; { TMacros.Create }

destructor TMacros.Destroy;
begin
  FreeAndNil(FChapterCounters);
  FreeAndNil(FCounters);
  FreeAndNil(FReplacements);
  inherited;
end; { TMacros.Destroy }

procedure TMacros.AddProblem(const problemMsg: string);
begin
  FProblems.Add(problemMsg + ' [line #' + FLineNumber.ToString + ']');
end; { TMacros.AddProblem }

function TMacros.AnchorLinkMacro(const macro, params: string; var replacement: string):
  boolean;
begin
  replacement := '[<@r:?' + params + '>](<@r:#' + params + '>)';
  Result := true;
end; { TMacros.AnchorLinkMacro }

function TMacros.AnchorMacro(const macro, params: string; var replacement: string): boolean;
begin
  replacement := StringReplace(macro, '<@a:', '<@r:#', []);
  Result := true;
end; { TMacros.AnchorMacro }

procedure TMacros.ApplyTo(const writer: IWriter; var problems: TArray<string>);
begin
  FProblems := TList<string>.Create;
  try
    FLineNumber := 0;
    writer.ForEachLine(ReplaceReferences);
    FLineNumber := 0;
    writer.ForEachLine(IncludeFiles);
    problems := FProblems.ToArray;
  finally FreeAndNil(FProblems); end;
end; { TMacros.ApplyTo }

function TMacros.ApplyTo(const lines: TArray<string>; var problems: TArray<string>):
  TArray<string>;
begin
  SetLength(Result, Length(lines));
  FProblems := TList<string>.Create;
  try
    for var iLine := Low(lines) to High(lines) do
      Result[iLine] := ReplaceReferences(lines[iLine]);
    problems := FProblems.ToArray;
  finally FreeAndNil(FProblems); end;
end; { TMacros.ApplyTo }

function TMacros.DefineMacro(const macro, params: string; var replacement: string):
  boolean;
begin
  // <@d:ChExamples=_chapter>
  // <@d:tip={class: blurb}>

  var param := params.Split(['=']);
  if Length(param) <> 2 then
    Exit(SetError('Malformed macro parameters: ' + macro));

  var value: string;
  if FReplacements.TryGetValue(param[0], value) then
    Exit(SetError('Value ' + param[0] + ' is already defined (' + value + '): ' + macro));

  if SameText(param[1], CThisChapter) then begin
    FReplacements.AddOrSetValue(param[0], FChapterNumber.ToString);
    FReplacements.AddOrSetValue('$' + param[0], FChapterName);
  end
  else if SameText(param[1], CThisSection) then
    FReplacements.AddOrSetValue('$' + param[0], FSectionName)
  else
    FReplacements.AddOrSetValue(param[0], param[1].Trim(['"','“','”']));
  replacement := '';

  Result := true;
end; { TMacros.DefineMacro }

function TMacros.IncludeFiles(const line: string): string;
var
  errMsg     : string;
  reader     : IReader;
  replacement: string;
begin
  Result := line;
  var startPos := 1;
  repeat
    var match := FIncludeMatcher.Match(Result, startPos);
    if not match.Success then
      break; //repeat

    if (match.Groups.Count <> 2) or (match.Groups[1].Value = '') then begin
      AddProblem('Malformed macro: ' + match.Value);
      Exit;
    end;

    var fileName := FGlobal.LeanpubManuscriptFolder + match.Groups[1].Value;
    reader := CreateReader(fileName, errMsg);
    if not assigned(reader) then
      replacement := ''
    else begin
      replacement := string.Join(#13, reader.GetAll);
      if not replacement.EndsWith(#13) then
        replacement := replacement + #13;
    end;

    Delete(Result, match.Index, match.Length);
    Insert(replacement, Result, match.Index);
    startPos := match.Index + Length(replacement);
  until false;
end; { TMacros.IncludeFiles }

function TMacros.IncludeMacro(const macro, params: string; var replacement: string): boolean;
begin
  replacement := macro;
  Result := true;
end; { TMacros.IncludeMacro }

function TMacros.NumberChapterMacro(const macro, params: string; var replacement: string): boolean;
begin
  // <@N:table=table3by2>

  var param := params.Split(['=']);
  if (Length(param) = 0) or (Length(param) > 2) then
    Exit(SetError('Malformed macro parameters: ' + macro));

  if Length(param) = 2 then begin
    var value: string;
    if FReplacements.TryGetValue(param[1], value) then
      Exit(SetError('Value ' + param[1] + ' is already defined (' + value + '): ' + macro));
  end;

  var counter: integer;
  if not FChapterCounters.TryGetValue(param[0], counter) then
    counter := 0;
  Inc(counter);
  FChapterCounters.AddOrSetValue(param[0], counter);
  replacement := FChapterNumber.ToString + '.' + counter.ToString;

  if Length(param) = 2 then begin
    FReplacements.AddOrSetValue(param[1], replacement);
    FLastAutoNumberID := param[1];
  end;

  Result := true;
end; { TMacros.NumberChapterMacro }

function TMacros.NumberMacro(const macro, params: string;
  var replacement: string): boolean;
begin
  // <@n:table=table3by2>

  var param := params.Split(['=']);
  if (Length(param) = 0) or (Length(param) > 2) then
    Exit(SetError('Malformed macro parameters: ' + macro));

  if Length(param) = 2 then begin
    var value: string;
    if FReplacements.TryGetValue(param[1], value) then
      Exit(SetError('Value ' + param[1] + ' is already defined (' + value + '): ' + macro));
  end;

  var counter: integer;
  if not FCounters.TryGetValue(param[0], counter) then
    counter := 0;
  Inc(counter);
  FCounters.AddOrSetValue(param[0], counter);
  replacement := counter.ToString;

  if Length(param) = 2 then begin
    FReplacements.AddOrSetValue(param[1], replacement);
    FLastAutoNumberID := param[1];
  end;

  Result := true;
end; { TMacros.NumberMacro }

function TMacros.Process(var line: string): boolean;
begin
  FLastAutoNumberID := '';
  var startPos := 1;
  repeat
    var match := FMacroMatcher.Match(line, startPos);
    if not match.Success then
      break; //repeat

    if (match.Groups.Count < 3) or (match.Groups[1].Value = '') then
      Exit(SetError('Malformed macro: ' + match.Value));

    if (Length(match.Groups[1].Value) <> 1)
       or (not CharInSet(match.Groups[1].Value[1], ['a'..'z', 'A'..'Z']))
       or (not assigned(FDispatcher[match.Groups[1].Value[1]]))
    then
      Exit(SetError('Unrecognized macro command "' + match.Groups[1].Value[1] + '": '
                    + match.Groups[1].Value));

    var replacement: string;
    if not FDispatcher[match.Groups[1].Value[1]](match.Value, match.Groups[2].Value, replacement) then
      Exit(false);

    Delete(line, match.Index, match.Length);
    Insert(replacement, line, match.Index);

    startPos := match.Index + IfThen(replacement <> match.Value, 0, Length(replacement));
  until false;

  Result := true;
end; { TMacros.Process }

procedure TMacros.RecordCaptionAnchor(const anchor: string);
begin
  if FLastAutoNumberID <> '' then
    FReplacements.Add('#' + FLastAutoNumberID, '#' + anchor);
end; { TMacros.RecordCaptionAnchor }

procedure TMacros.RecordSpecialAnchor(const anchor: string);
begin
  FReplacements.Add('#' + anchor, '#' + anchor);
end; { TMacros.RecordSpecialAnchor }

function TMacros.ReferenceMacro(const macro, params: string; var replacement: string):
  boolean;
begin
  //<@r:_chapter>. <@r:table3by2> and table <@r:table2by3> (Chapter <@r:ChExamples>)

  if SameText(params, CThisChapter) then
    replacement := FChapterNumber.ToString
  else if not FReplacements.TryGetValue(params, replacement) then
    replacement := macro;

  Result := true;
end; { TMacros.ReferenceMacro }

function TMacros.ReferenceNameMacro(const macro, params: string;
  var replacement: string): boolean;
begin
  //<@R:appendix_scriv4lean>

  if SameText(params, CThisChapter) then
    replacement := FChapterName
  else if SameText(params, CThisSection) then
    replacement := FSectionName
  else
    replacement := StringReplace(macro, '<@R:', '<@r:$', []);

  Result := true;
end; { TMacros.ReferenceNameMacro }

function TMacros.ReplaceReferences(const line: string): string;
begin
  Inc(FLineNumber);
  Result := line;
  var startPos := 1;
  repeat
    var match := FReferenceMatcher.Match(Result, startPos);
    if not match.Success then
      break; //repeat

    if (match.Groups.Count <> 2) or (match.Groups[1].Value = '') then begin
      AddProblem('Malformed macro: ' + match.Value);
      Exit;
    end;

    var param := match.Groups[1].Value;
    var value: string;
    var found := FReplacements.TryGetValue(param, value);
    if (not found) and param.StartsWith('?') then begin
      found := FReplacements.TryGetValue('$' + Copy(param, 2), value);
      if not found then
        found := FReplacements.TryGetValue(Copy(param, 2), value);
    end;
    if not found then begin
      AddProblem('Value ' + match.Groups[1].Value + ' not found: ' + match.Value);
      Exit;
    end;

    Delete(Result, match.Index, match.Length);
    Insert(value, Result, match.Index);
    startPos := match.Index + Length(value);
  until false;
end; { TMacros.ReplaceReferences }

procedure TMacros.SetChapterName(const name: string);
begin
  FChapterName := name;
end; { TMacros.SetChapterName }

procedure TMacros.SetChapterNumber(number: integer);
begin
  FChapterNumber := number;
  FChapterCounters.Clear;
end; { TMacros.SetChapterNumber }

procedure TMacros.SetSectionName(const name: string);
begin
  FSectionName := name;
end; { TMacros.SetSectionName }

end.
