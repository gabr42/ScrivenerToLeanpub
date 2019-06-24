unit S4L.Processor;

interface

uses
  S4L.Errors, S4L.Global, S4L.Anchors, S4L.Context, S4L.References,
  S4L.TODOWriter, S4L.Images, S4L.Captions, S4L.Format, S4L.Macros, S4L.Notes,
  S4L.Processor.Config;

type

  IProcessor = interface(IErrorBase) ['{A800FADD-873D-4931-8B31-87B728C2FEDE}']
    function  GetWarnings: TArray<string>;
    function  Run(options: TProcessorOptions): boolean;
    property Warnings: TArray<string> read GetWarnings;
  end; { IProcessor }

function CreateProcessor(const global: IGlobal; const anchors: IAnchors;
  const context: IContext; const references: IReferences;
  const todoWriter: ITODOWriter; const images: IImages;
  const captions: ICaptions; const macros: IMacros;
  const format: IFormat; const notes: INotes): IProcessor;

implementation

uses
  System.SysUtils, System.StrUtils, System.Classes, System.IOUtils, System.Math,
  System.RegularExpressions, System.Generics.Defaults, System.Generics.Collections,
  S4L.Platform, S4L.Common, S4L.Metadata, S4L.Writer,
  S4L.Processor.State, S4L.Processor.TableFormatter;

const
  CFrontMatterMarker   = '<$leanpub:frontmatter>';
  CBackMatterMarker    = '<$leanpub:backmatter>';
  CPartMarker          = '<$leanpub:part>';
  CChapterMarker       = '<$leanpub:chapter>';
  CTODOMarker          = '<$leanpub:todo>';
  CTODOEndMarker       = '</$leanpub:todo>';
  CFootnoteMarker      = '<$leanpub:footnote>';
  CFootnoteEndMarker   = '</$leanpub:footnote>';
  CEndnoteMarker       = '<$leanpub:endnote>';
  CEndnoteEndMarker    = '</$leanpub:endnote>';
  CCenterMarker        = '<$leanpub:center>';
  CCenterEndMarker     = '</$leanpub:center>';

  // regex markers
  CPoetryMarker        = '<\$leanpub:poetry>';
  CPoetryEndMarker     = '</\$leanpub:poetry>';
  CCaptionMarker       = '<\$leanpub:caption:(\p{L}+)>';
  CCaptionEndMarker    = '</\$leanpub:caption:(\p{L}+)>';
  CListOfMarker        = '<\$leanpub:listof:(\p{L}+)>';
  CListOfEndMarker     = '</\$leanpub:listof:(\p{L}+)>';
  CBibMarker           = '<\$leanpub:bib>';
  CBibEndMarker        = '</\$leanpub:bib>';

  // Markua markers are their own regex; used in both ways!
  CBlockQuoteMarker    = '{blockquote}';
  CBlockQuoteEndMarker = '{/blockquote}';
  CAsideMarker         = '{aside}';
  CAsideEndMarker      = '{/aside}';
  CBlurbMarker         = '{blurb}';
  CBlurbEndMarker      = '{/blurb}';

  CTOFTagCaption   = 'Caption';
  CTOFTagReference = 'Reference';

  CCodeBlock = '```';
  CComment   = '%%';

  CImagesSubfolder     = 'images';
  CImageFileTemplate   = 'image-%d';
  CImageAnchorTemplate = 'scriv4lean-images-%d';
  CImageExtPlaceholder = '.$FILENAME$';
  CTableAnchorTemplate = 'scriv4lean-table-%s-%d';

type
  IStateProcessor = interface(IErrorBase) ['{8FA59B76-2B13-4B0E-A474-65AC0D3BEECC}']
    function Step(var nextState: State): boolean;
  end; { IStateProcessor }

  TStateProcessor = class(TErrorBase, IStateProcessor)
  strict private
    FBibMarker        : TRegEx;
    FCitationMatcher  : TRegEx;
    FEOLCaptionMatcher: TRegEx;
    FGlobal           : IGlobal;
    FPoetryMarker     : TRegEx;
    FProcessorState   : IProcessorState;
    FReferenceMatcher : TRegEx;
    FListOfMarker     : TRegEx;
    FWarningHook      : TProc<string>;
    FWeirdMatcher     : TRegEx;
  strict protected
    procedure AddWarning(const message: string); overload;
    procedure AddWarning(const message: string; const params: array of const); overload;
    function  CleanupCaption(const caption: string): string;
    function  Expect(const name, pattern: string; var line: string): boolean;
    function  ExtractTODOs(var line: string): boolean;
    procedure FixWeirdness(var line: string); protected
    procedure ProcessCitations(var line: string);
    procedure RecordReferences(var line: string);
    procedure PreProcessCenteredText(var line: string);
    function  MakeAnchor(const name: string): string;
    function  MakeFileName(const attrName, intName: string): string;
    function  ReadOneBlock(template: TStrings; const tableName: string;
      const beginMarker, endMarker: TRegEx; var name, trailer: string): boolean;
    function  SetError(const errorMsg: string): boolean; overload; override;
    function  SwitchState(const line: string; var nextState: State): boolean;
  public
    constructor Create(const global: IGlobal; processorState: IProcessorState;
      const warningHook: TProc<string>); virtual;
    function  GetLine(var line: string): boolean;
    class function IsMeta(const s: string): boolean;
    function  ReadBlock(template: TStrings; const tableName: string;
      const beginMarker, endMarker: TRegEx; var name, trailer: string): boolean;
    function  Step(var nextState: State): boolean; virtual; abstract;
    property Global: IGlobal read FGlobal;
    property ProcessorState: IProcessorState read FProcessorState;
  end; { TStateProcessor }

  TBOFProcessor = class(TStateProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { TBOFProcessor }

  TEOFProcessor = class(TStateProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { TEOFProcessor }

  THeadingProcessor = class(TStateProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { THeadingProcessor }

  TPartProcessor = class(TStateProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { TPartProcessor }

  TBaseChapterProcessor = class(TStateProcessor)
  public
    function StartChapter(const line: string; content: ContentMode;
      part: BookPart; var nextState: State): boolean;
  end; { TBaseChapterProcessor }

  TChapterProcessor = class(TBaseChapterProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { TChapterProcessor }

  TFrontMatterProcessor = class(TBaseChapterProcessor)
    function Step(var nextState: State): boolean; override;
  end; { TFrontMatterProcessor }

  TBackMatterProcessor = class(TBaseChapterProcessor)
    function Step(var nextState: State): boolean; override;
  end; { TBackMatterProcessor }

  TContentProcessor = class(TStateProcessor)
  strict private
    FCaptionMatcher   : TRegEx;
    FCaptionEndMatcher: TRegEx;
    FImageMatcher     : TRegEx;
    FLastTableAnchor  : TDictionary<string, integer>;
    FResourceMatcher  : TRegEx;
    FSectionMatcher   : TRegEx;
    FTableMatcher     : TRegEx;
  strict protected
    function  CreateTableAnchor(const tableName: string): string;
    function  FilterCaption(var caption: string; const anchor: string): boolean; overload;
    function  FilterCaption(var caption: string; const anchor: string;
      const matchStart: TMatch): boolean; overload;
    function  IsSection(const line: string): boolean;
    function  MakeImageFileName(idxImage: integer; const ext: string): string;
    function  ProcessGenericCaption(var line: string): boolean;
    function  ProcessImages(var line: string): boolean;
    function  ProcessResource(const line: string): string;
    function  WriteImage(const imageRef, sourceFile: string): boolean;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    function  Step(var nextState: State): boolean; override;
  end; { TContentProcessor }

  TCodeProcessor = class(TStateProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { TCodeProcessor }

  TTableProcessor = class(TStateProcessor)
  public
    function Step(var nextState: State): boolean; override;
  end; { TTableProcessor }

  TTemplateProcessor = class(TStateProcessor)
  strict protected
    function FillTemplate(template: TStrings;
      const mapper: TFunc<string, string>): TArray<string>;
    function ReplaceAllTags(const line: string;
      const mapper: TFunc<string, string>): string;
  public
  end; { TTemplateProcessor }

  TListOfProcessor = class(TTemplateProcessor)
  strict private
    FBeginMarker: TRegEx;
    FEndMarker  : TRegEx;
  strict protected
    function  ReplaceTag(const tag: string; const captionInfo: TCaptionInfo): string;
  public
    procedure AfterConstruction; override;
    function  Step(var nextState: State): boolean; override;
  end; { TListOfProcessor }

  TBibProcessor = class(TTemplateProcessor)
  strict private
    FBeginMarker: TRegEx;
    FEndMarker  : TRegEx;
  public
    procedure AfterConstruction; override;
    function  Step(var nextState: State): boolean; override;
  end; { TBibProcessor }

  TPoetryProcessor = class(TStateProcessor)
  strict private
    FBeginMarker: TRegEx;
    FEndMarker  : TRegEx;
  public
    procedure AfterConstruction; override;
    function  Step(var nextState: State): boolean; override;
  end; { TPoetryProcessor }

  TQuoteProcessor = class(TStateProcessor)
  public
    function  Step(var nextState: State): boolean; override;
  end; { TQuoteProcessor }

  TProcessor = class(TErrorBase, IProcessor)
  strict private
    FGlobal        : IGlobal;
    FProcessor     : array [State] of IStateProcessor;
    FProcessorState: IProcessorState;
    FWarnings      : TList<string>;
  strict protected
    function  CheckReferences: boolean;
    function  GetWarnings: TArray<string>;
    procedure PostprocessAnchors;
    procedure PostprocessFootEndNotes;
    procedure PostprocessMacros;
    procedure PostprocessQuotes;
    procedure ProcessNotes(const startMarker, endMarker: string;
      const noteFactory: TFunc<INote>);
    procedure WarningCollector(message: string);
  public
    constructor Create(const global: IGlobal; const anchors: IAnchors;
      const context: IContext; const references: IReferences;
      const todoWriter: ITODOWriter; const images: IImages;
      const captions: ICaptions; const macros: IMacros; const format: IFormat;
      const notes: INotes);
    destructor  Destroy; override;
    function Run(options: TProcessorOptions): boolean;
    property Warnings: TArray<string> read GetWarnings;
  end; { TProcessor }

{ exports }

function CreateProcessor(const global: IGlobal; const anchors: IAnchors;
  const context: IContext; const references: IReferences; const todoWriter: ITODOWriter;
  const images: IImages; const captions: ICaptions; const macros: IMacros;
  const format: IFormat; const notes: INotes): IProcessor;
begin
  Result := TProcessor.Create(global, anchors, context, references, todoWriter,
              images, captions, macros, format, notes);
end; { CreateProcessor }

{ TStateProcessor }

constructor TStateProcessor.Create(const global: IGlobal; processorState: IProcessorState;
  const warningHook: TProc<string>);
begin
  inherited Create;
  FGlobal := global;
  FProcessorState := processorState;
  FWarningHook := warningHook;
  FListOfMarker := TRegEx.Create(CListOfMarker);
  FBibMarker := TRegEx.Create(CBibMarker);
  FPoetryMarker := TRegEx.Create(CPoetryMarker);
  FWeirdMatcher := TRegEx.Create('^<\$leanpub:.*>(?<blockStyle>{(blurb|aside|blockquote)})');
  FCitationMatcher := TRegEx.Create('\[([A-Za-z0-9]+)\](?![(\]])');
  FReferenceMatcher := TRegEx.Create(
    '(?<reference>'
      + '(?<!\\)\[(?<caption>[^\[\]]*?[^\\]?)\]'
      + '\((?<anchor>.*?)\)'
    + ')');
  FEOLCaptionMatcher := TRegEx.Create('\[([^\]\]]+)\]\s*$');
end; { TStateProcessor.Create }

procedure TStateProcessor.AddWarning(const message: string);
begin
  FWarningHook(Format('%s [line #%d]', [message, Global.ScrivenerReader.CurrentLine]));
end; { TStateProcessor.AddWarning }

procedure TStateProcessor.AddWarning(const message: string; const params: array of const);
begin
  AddWarning(Format(message, params));
end; { TStateProcessor.AddWarning }

function TStateProcessor.CleanupCaption(const caption: string): string;
begin
  // special cleanup of weird cross-references
  Result := StringReplace(
            StringReplace(
            StringReplace(
            StringReplace(caption, '<$leanpub:chapter> - <$mmdhn> ', '', []),
                                   '<$leanpub:frontmatter> - <$mmdhn> ', '', []),
                                   '<$leanpub:backmatter> - <$mmdhn> ', '', []),
                                   '<$leanpub:part> - <$mmdhn> ', '', []);
end; { TStateProcessor.CleanupCaption }

function TStateProcessor.Expect(const name, pattern: string; var line: string): boolean;
begin
  var regex := TRegEx.Create(pattern, [roIgnoreCase]);
  repeat
    if not GetLine(line) then
      Exit(SetError('Expected %s, encountered end of file', [name]));
    if line = '' then
      continue; //repeat
    var match := regex.Match(line);
    if not match.Success then
      Exit(SetError('Expected %s, got: %s', [name, line]))
    else begin
      line := match.Groups[1].Value;
      Exit(true);
    end;
  until false;
end; { TStateProcessor.Expect }

function TStateProcessor.ExtractTODOs(var line: string): boolean;
begin
  repeat
    var pStart := Pos(CTODOMarker, line);
    var pEnd := Pos(CTODOEndMarker, line);
    if (pStart = 0) and (pEnd > 0) then
      Exit(SetError('Found end TODO marker without a start marker: ' + line));
    if (pStart > 0) and (pEnd = 0) then
      Exit(SetError('Found start TODO marker without an end marker: ' + line));
    if pEnd < pStart then
      Exit(SetError('Found end TODO marker before the start marker: ' + line));
    if pStart = 0 then
      Exit(true);

    var todo := Copy(line, pStart + Length(CTODOMarker), pEnd - pStart - Length(CTODOMarker));
    Delete(line, pStart, pEnd - pStart + Length(CTODOEndMarker));

    if not ProcessorState.TODOWriter.Add(ProcessorState.Context.Path, todo) then
      Exit(SetError(ProcessorState.TODOWriter.ErrorMsg));
  until false;
end; { TStateProcessor.ExtractTODOs }

procedure TStateProcessor.FixWeirdness(var line: string);
begin
  var match := FWeirdMatcher.Match(line);
  if not match.Success then
    Exit;

  var blockStyle := match.Groups['blockStyle'];
  Delete(line, blockStyle.Index, blockStyle.Length);
  Insert(blockStyle.Value, line, 1);
end; { TStateProcessor.FixWeirdness }

function TStateProcessor.GetLine(var line: string): boolean;
begin
  if not Global.ScrivenerReader.GetLine(line) then
    Exit(false);

  if not ProcessorState.Macros.Process(line) then
    Exit(SetError(ProcessorState.Macros.ErrorMsg));

  PreProcessCenteredText(line);

  Result := ExtractTODOs(line);
end; { TStateProcessor.GetLine }

class function TStateProcessor.IsMeta(const s: string): boolean;
begin
  Result := s.StartsWith('{') and s.EndsWith('}');
end; { TStateProcessor.IsMeta }

function TStateProcessor.MakeAnchor(const name: string): string;
begin
  // Tries to mimic Scrivener behaviour for generating anchors from headings.
  // Definitely NOT there yet ...

  Result := name;
  for var iCh := Length(Result) downto 1 do begin
    if CharInSet(Result[iCh], ['a'..'z', 'A'..'Z', '0'..'9']) then
      continue; //for
    if Result[iCh] = ' ' then
      Result[iCh] := '_'
    else
      Delete(Result, iCh, 1);
  end;

  Result := Result.TrimRight(['_']);

  if ProcessorState.Anchors.Has(Result) then begin
    var anchor: string;
    var cnt := 1;
    repeat
      anchor := Result + '-' + cnt.ToString;
      Inc(cnt);
    until not ProcessorState.Anchors.Has(anchor);
    Result := anchor;
  end;
end; { TStateProcessor.MakeAnchor }

function TStateProcessor.MakeFileName(const attrName, intName: string): string;
begin
  Result := IfThen(attrName <> '', attrName, intName);
  if Pos('.', Result) = 0 then
    Result := Result + '.txt';
end; { TStateProcessor.MakeFileName }

procedure TStateProcessor.PreProcessCenteredText(var line: string);
begin
  if line.StartsWith(CCenterMarker) then begin
    Global.ScrivenerReader.PushBack(Copy(line, Length(CCenterMarker) + 1));
    line := '{blurb, class: center}';
  end;

  if line.EndsWith(CCenterEndMarker) then begin
    Delete(line, Length(line) - Length(CCenterEndMarker) + 1, Length(line));
    Global.ScrivenerReader.PushBack(CBlurbEndMarker);
  end;
end; { TStateProcessor.PreProcessCenteredText }

procedure TStateProcessor.ProcessCitations(var line: string);
begin
  if not assigned(Global.BibTeX) then
    Exit;

  var startPos := 1;

  repeat
    var match := FCitationMatcher.Match(line, startPos);
    if not match.Success then
      break; //repeat

    var citationKey := match.Groups[1].Value;
    var anchor: string;
    if not Global.BibTeX.HasCitation(citationKey, anchor) then
      Inc(startPos, match.Length)
    else begin
      if optCheckURLs in ProcessorState.Options then
        Global.URLChecker.Add(Global.BibTeX.GetCitationURL(citationKey));
      if optNumberCitations in ProcessorState.Options then
        citationKey := Global.BibTeX.GetCitationNumber(citationKey).ToString;
      var citation := ProcessorState.Format.Reference('[' + citationKey + ']', anchor);
      Delete(line, match.Index, match.Length);
      Insert(citation, line, match.Index);
      Inc(startPos, Length(citation));
    end;
  until false;
end; { TStateProcessor.ProcessCitations }

function TStateProcessor.ReadBlock(template: TStrings; const tableName: string; //FI:W521
  const beginMarker, endMarker: TRegEx; var name, trailer: string): boolean;
var
  line: string;
begin
  name := '';

  repeat
    if not ReadOneBlock(template, tableName, beginMarker, endMarker, name, trailer) then
      Exit(false);

    if trailer <> '' then
      Exit(true);

    if not GetLine(line) then
      Exit(true);

    Global.ScrivenerReader.PushBack(line);

    FixWeirdness(line);

    var nextMatch := beginMarker.Match(line);
    if not (nextMatch.Success and (nextMatch.Index = 1)) then
      Exit(true);
  until false;
end; { TStateProcessor.ReadBlock }

function TStateProcessor.ReadOneBlock(template: TStrings; const tableName: string; //FI:W521
  const beginMarker, endMarker: TRegEx; var name, trailer: string): boolean;
var
  line: string;
begin
  if not GetLine(line) then
    Exit(SetError('Expected ' + tableName));

  FixWeirdness(line);

  var matchStart := beginMarker.Match(line);
  if not matchStart.Success then
    Exit(SetError('Expected ' + tableName + ' begin marker'));

  if matchStart.Groups.Count > 1 then
    name := matchStart.Groups[1].Value;

  if matchStart.Index > 1 then begin
    Global.ContentWriter.WriteLine(Copy(line, 1, matchStart.Index - 1));
    line := line.Remove(0, matchStart.Index - 1);
  end;
  line := line.Remove(0, matchStart.Length);

  repeat
    RecordReferences(line);
    ProcessCitations(line);

    var matchEnd := endMarker.Match(line);
    if matchEnd.Success then begin
      template.Add(Copy(line, 1, matchEnd.Index - 1));
      line := line.Remove(0, matchEnd.Index - 1 + matchEnd.Length);
      trailer := line;
      if (matchStart.Groups.Count <> matchEnd.Groups.Count)
         or ((matchStart.Groups.Count > 1) and (not SameText(matchStart.Groups[1].Value, matchEnd.Groups[1].Value)))
      then
        Exit(SetError('Begin marker ' + matchStart.Value + ' is different from end marker ' + matchEnd.Value))
      else
        Exit(true);
    end;

    template.Add(line);
    if not GetLine(line) then
      Exit(SetError('Expected ' + tableName + ' end marker'));
  until false;
end; { TStateProcessor.ReadOneBlock }

procedure TStateProcessor.RecordReferences(var line: string);
begin

  if Pos('[<@r:?appendix_autoNumbering>](<@r:#appendix_autoNumbering>)', line) > 0 then
    sleep(0);

  var startPos := 1;
  repeat
    var match := FReferenceMatcher.Match(line, startPos);
    if not match.Success then
      Exit;

    var anchor := match.Groups['anchor'].Value;
    if (anchor = '') or anchor.StartsWith('#') then begin
      startPos := match.Index + match.Length;
      continue; //repeat
    end;

    var caption := CleanupCaption(match.Groups['caption'].Value);
    var matchIndex := match.Index;
    var matchLength := match.Length;
    var correction := 0;
    var eolCaption := FEOLCaptionMatcher.Match(Copy(line, 1, matchIndex - 1));
    if eolCaption.Success then begin
      caption := eolCaption.Groups[1].Value;
      Delete(line, eolCaption.Index, eolCaption.Length);
      correction := eolCaption.Length;
    end;

    var reference: string;
    if (anchor.StartsWith('<@')
         or anchor.StartsWith('<'#$200B'@')  // zero widht spacce
         or anchor.StartsWith('<'#$FEFF'@')) // zero width no-break space
       and anchor.EndsWith('>')
    then
      reference := match.Value
    else if anchor.StartsWith('<') and anchor.EndsWith('>') then begin
      reference := ProcessorState.Format.HttpReference(caption, Copy(anchor, 2, Length(anchor) - 2));
      if optCheckURLs in ProcessorState.Options then
        Global.URLChecker.Add(Copy(anchor, 2, Length(anchor) - 2));
    end
    else if anchor.StartsWith('http:') or anchor.StartsWith('https:') then begin
      reference := ProcessorState.Format.HttpReference(caption, anchor);
      if optCheckURLs in ProcessorState.Options then
        Global.URLChecker.Add(anchor);
    end
    else begin
      reference := ProcessorState.Format.Reference(caption, anchor);
      ProcessorState.References.Add(anchor, reference);
    end;

    Delete(line, matchIndex - correction, matchLength);
    Insert(reference, line, matchIndex - correction);

    startPos := matchIndex - correction + Length(reference);
  until false;
end; { TStateProcessor.RecordReferences }

function TStateProcessor.SetError(const errorMsg: string): boolean;
begin
  Result := inherited SetError(errorMsg + ' [line #'
                               + Global.ScrivenerReader.CurrentLine.ToString + ']');
end; { TStateProcessor.SetError }

function TStateProcessor.SwitchState(const line: string; var nextState: State): boolean;
begin
  Result := false;
  if SameText(line, CPartMarker) then begin
    nextState := State.Part;
    Exit(true);
  end;
  if SameText(line, CChapterMarker) then begin
    nextState := State.Chapter;
    Exit(true);
  end;
  if SameText(line, CFrontMatterMarker) then begin
    nextState := State.FrontMatter;
    Exit(true);
  end;
  if SameText(line, CBackMatterMarker) then begin
    nextState := State.BackMatter;
    Exit(true);
  end;
  if FListOfMarker.IsMatch(line) then begin
    Global.ScrivenerReader.PushBack(line);
    nextState := State.ListOf;
    Exit(true);
  end;
  if FBibMarker.IsMatch(line) then begin
    Global.ScrivenerReader.PushBack(line);
    nextState := State.Bibliography;
    Exit(true);
  end;
  if FPoetryMarker.IsMatch(line) then begin
    Global.ScrivenerReader.PushBack(line);
    nextState := State.Poetry;
    Exit(true);
  end;
  if line.StartsWith(CBlockQuoteMarker)
     or line.StartsWith(CAsideMarker)
     or line.StartsWith(CBlurbMarker)
  then begin
    Global.ScrivenerReader.PushBack(line);
    nextState := State.Quote;
    Exit(true);
  end;
end; { TStateProcessor.SwitchState }

{ TBOFProcessor }

function TBOFProcessor.Step(var nextState: State): boolean;
begin
  // Skip project metadata, then start scanning for section headers.

  if not Global.ScrivenerReader.ReadMetadata(CreateMetadata) then
    Exit(SetError(Global.ScrivenerReader.ErrorMsg));

  nextState := State.Heading;
  Result := true;
end; { TBOFProcessor.Step }

{ TEOFProcessor }

function TEOFProcessor.Step(var nextState: State): boolean;
begin
  Result := SetError('Can''t move from the end state');
end; { TEOFProcessor.Step }

{ THeadingProcessor }

function THeadingProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  while GetLine(line) do begin
    if SwitchState(line, nextState) then
      Exit(true);

    if line <> '' then
      Exit(SetError('Expected Part/Chapter/Appendix marker, got: %s', [line]));
  end;

  nextState := State.EOF;
  Result := true;
end; { THeadingProcessor.Step }

{ TPartProcessor }

function TPartProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  if not Expect('Part heading', '^#?\s*(.*?)\s*#?$', line) then
    Exit(false);

  var metadata := CreateMetadata;
  if not Global.ScrivenerReader.ReadMetadata(metadata) then
    Exit(SetError(Global.ScrivenerReader.ErrorMsg));

  ProcessorState.PartCount := ProcessorState.PartCount + 1;

  ProcessorState.LastPartBookmark := Global.ContentWriter.CreateBookmark;

  Global.ContentWriter.WriteLine(ProcessorState.Format.Part(line));
  Global.ContentWriter.WriteLine('');
  ProcessorState.Context.Add(line, 1);

  nextState := State.Content;
  Result := true;
end; { TPartProcessor.Step }

function TBaseChapterProcessor.StartChapter(const line: string;
  content: ContentMode; part: BookPart; var nextState: State): boolean;
begin
  var metadata := CreateMetadata;
  if not Global.ScrivenerReader.ReadMetadata(metadata) then
    Exit(SetError(Global.ScrivenerReader.ErrorMsg));

  if ProcessorState.Content < content then begin
    var delim: TArray<string> := ProcessorState.Format.BookPartDelimiter(part);
    if Length(delim) > 0 then
      if assigned(ProcessorState.LastPartBookmark) then
        ProcessorState.LastPartBookmark.WriteLine(delim)
      else
        Global.ContentWriter.WriteLine(delim);
    ProcessorState.Content := content;
  end;

  ProcessorState.LastPartBookmark := nil;

  var filteredLine := line;
  filteredLine := filteredLine.Trim;
  ProcessorState.Macros.SetChapterName(filteredLine);

  var anchor := MakeAnchor(filteredLine);

  var nextLine: string;
  if GetLine(nextLine) then begin
    nextLine := Trim(nextLine);
    if nextLine.StartsWith('{#') and nextLine.EndsWith('}') then begin
      anchor := Copy(nextLine, 3, Length(nextLine) - 3);
      var macro := '<@d:' + anchor + '=_chapter>';
      ProcessorState.Macros.Process(macro);
      ProcessorState.Macros.RecordSpecialAnchor(anchor);
    end
    else
      Global.ScrivenerReader.PushBack(nextLine);
  end;

  if not ProcessorState.Anchors.Add(filteredLine, anchor, Global.ScrivenerReader.CurrentLine) then
    AddWarning(ProcessorState.Anchors.ErrorMsg);

  Global.ContentWriter.WriteLine([
    ProcessorState.Format.Anchor(anchor),
    ProcessorState.Format.Chapter(filteredLine)]);
  Global.ContentWriter.WriteLine('');
  ProcessorState.Context.Add(filteredLine, 1 + IfThen(ProcessorState.PartCount > 0, 1, 0));

  nextState := State.Content;
  Result := true;
end; { TBaseChapterProcessor.StartChapter }

{ TChapterProcessor }

function TChapterProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  // Chapters start with '# ' when not using Parts; and with '## ' when using Parts.
  if not Expect('Chapter heading', '^##?\s*(.*) ##?$', line) then
    Exit(false);

  ProcessorState.ChapterCount := ProcessorState.ChapterCount + 1;
  ProcessorState.Macros.SetChapterNumber(ProcessorState.ChapterCount);

  if not StartChapter(line, ContentMode.MainMatter, BookPart.MainMatter, nextState) then
    Exit(false);

  Result := true;
end; { TChapterProcessor.Step }

{ TFrontMatterProcessor }

function TFrontMatterProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  if not GetLine(line) then
    Exit(SetError('Unexpected end of file'));
  if line <> '' then
    Exit(SetError('Expected empty line while parsing front matter, got: ' + line));

  // Front matter chapters start without '# '; a '#' represents a section
  if not Expect('Front matter heading', '^\s*(.*)$', line) then
    Exit(false);

  Exit(StartChapter(line, ContentMode.FrontMatter, BookPart.FrontMatter, nextState));
end; { TFrontMatterProcessor.Step }

{ TBackMatterProcessor }

function TBackMatterProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  if not GetLine(line) then
    Exit(SetError('Unexpected end of file'));
  if line <> '' then
    Exit(SetError('Expected empty line while parsing back matter, got: ' + line));

  // Back matter chapters start without '# '; a '#' represents a section
  if not Expect('Back matter heading', '^#?\s*(.*?)#?$', line) then
    Exit(false);

  Exit(StartChapter(line, ContentMode.BackMatter, BookPart.BackMatter, nextState));
end; { TBackMatterProcessor.Step }

{ TContentProcessor }

procedure TContentProcessor.AfterConstruction;
begin
  FSectionMatcher := TRegEx.Create('^(#+)\s*(.*) #+$');
  FImageMatcher := TRegEx.Create(
    '(?<reference>'
      + '(?<!\\)!\[(?<caption>[^\[\]]*?[^\\]?)\]'
      + '\[(?<imageref>.*?)\]'
    + ')');
  FResourceMatcher := TRegEx.Create('^\[(?<reference>[^\^].*?)\]:\s*(?<resource>.*)$');
  FTableMatcher := TRegEx.Create('^({[^}]*?})?\|.*\|$');
  FCaptionMatcher := TRegEx.Create(CCaptionMarker);
  FCaptionEndMatcher := TRegEx.Create(CCaptionEndMarker);
  FLastTableAnchor := TDictionary<string, integer>.Create(
    TOrdinalIStringComparer(TIStringComparer.Ordinal));
end; { TContentProcessor.AfterConstruction }

procedure TContentProcessor.BeforeDestruction;
begin
  FreeAndNil(FLastTableAnchor);
  inherited;
end; { TContentProcessor.BeforeDestruction }

function TContentProcessor.CreateTableAnchor(const tableName: string): string;
var
  counter: integer;
begin
  if not FLastTableAnchor.TryGetValue(tableName, counter) then
    counter := 0;
  Inc(counter);
  FLastTableAnchor.AddOrSetValue(tableName, counter);
  Result := Format(CTableAnchorTemplate, [tableName, counter]);
end; { TContentProcessor.CreateTableAnchor }

function TContentProcessor.FilterCaption(var caption: string;
  const anchor: string; const matchStart: TMatch): boolean;
begin
  var matchEnd := FCaptionEndMatcher.Match(caption);
  if not (matchStart.Success and matchEnd.Success) then
    Exit(true);
  if (not matchStart.Success) and matchEnd.Success then
    Exit(SetError('Found end Caption marker without a start marker: ' + caption));
  if matchStart.Success and (not matchEnd.Success) then
    Exit(SetError('Found start Caption marker without an end marker: ' + caption));
  if matchEnd.Index < matchStart.Index then
    Exit(SetError('Found end Caption marker before the start marker: ' + caption));
  if (matchStart.Groups.Count <> matchEnd.Groups.Count)
     or ((matchStart.Groups.Count > 0) and (not SameText(matchStart.Groups[1].Value, matchEnd.Groups[1].Value)))
  then
    Exit(SetError('Begin marker ' + matchStart.Value + ' is different from end marker ' + matchEnd.Value));

  caption := Copy(caption, matchStart.Index + matchStart.Length,
                           matchEnd.Index - matchStart.Index - matchStart.Length);

  ProcessorState.Captions.Add(caption, anchor, matchStart.Groups[1].Value);

  Result := true;
end; { TContentProcessor.FilterCaption }

function TContentProcessor.FilterCaption(var caption: string;
  const anchor: string): boolean;
begin
  Result := FilterCaption(caption, anchor, FCaptionMatcher.Match(caption));
end; { TContentProcessor.FilterCaption }

function TContentProcessor.IsSection(const line: string): boolean;
begin
  var match := FSectionMatcher.Match(line);
  Result := match.Success;
  if Result then begin
    var depth := Length(match.Groups[1].Value);
    var realDepth := depth;
    if (ProcessorState.PartCount > 0) and (ProcessorState.Content = ContentMode.MainMatter) then
      Dec(realDepth);
    if (ProcessorState.Content in [ContentMode.FrontMatter, ContentMode.BackMatter]) then
      Inc(realDepth);
    var heading := match.Groups[2].Value;

    if not Global.ScrivenerReader.ReadMetadata(CreateMetadata) then
      Exit(SetError(Global.ScrivenerReader.ErrorMsg));

    ProcessorState.Macros.SetSectionName(heading);

    var anchor := MakeAnchor(heading);
    var nextLine: string; { TODO : This code has lots in common with TBaseChapterProcessor.StartChapter - unify }
    if GetLine(nextLine) then begin
      nextLine := Trim(nextLine);
      if nextLine.StartsWith('{#') and nextLine.EndsWith('}') then begin
        anchor := Copy(nextLine, 3, Length(nextLine) - 3);
        var macro := '<@d:' + anchor + '=_section>';
        ProcessorState.Macros.Process(macro);
        ProcessorState.Macros.RecordSpecialAnchor(anchor);
      end
      else
        Global.ScrivenerReader.PushBack(nextLine);
    end;

    Global.ContentWriter.WriteLine([
      ProcessorState.Format.Anchor(anchor),
      ProcessorState.Format.Section(heading, realDepth)]);

    Global.ContentWriter.WriteLine('');
    if not ProcessorState.Anchors.Add(heading, anchor, Global.ScrivenerReader.CurrentLine) then
      AddWarning(ProcessorState.Anchors.ErrorMsg);
    ProcessorState.Context.Add(heading, depth);
  end;
end; { TContentProcessor.IsSection }

function TContentProcessor.MakeImageFileName(idxImage: integer; const ext: string):
  string;
begin
  Result := IncludeTrailingPathDelimiter(CImagesSubfolder)
            + Format(CImageFileTemplate, [idxImage + 1])
            + ext;
end; { TContentProcessor.MakeImageFileName }

function TContentProcessor.ProcessGenericCaption(var line: string): boolean;
begin
  var captionMatch := FCaptionMatcher.Match(line);
  if captionMatch.Success then begin
    if captionMatch.Groups.Count < 1 then
      Exit(SetError('Found caption without a table name: ' + captionMatch.Value));

    var anchor := CreateTableAnchor(captionMatch.Groups[1].Value);
    if not FilterCaption(line, anchor, captionMatch) then
      Exit(false)
    else begin
      if assigned(ProcessorState.LastTableBookmark) then begin
        if assigned(ProcessorState.LastMetaBookmark) then
          ProcessorState.LastMetaBookmark.Replace('}',
            ', id: ' + anchor + '}')
        else
          ProcessorState.LastTableBookmark.WriteLine(
            ProcessorState.Format.Anchor(anchor))
      end
      else
        Global.ContentWriter.WriteLine(
          ProcessorState.Format.Anchor(anchor));
      ProcessorState.Macros.RecordCaptionAnchor(anchor);
      ProcessorState.LastTableBookmark := nil;
      Global.ContentWriter.WriteLine(ProcessorState.Format.CenteredCaption(line));
      line := '';
    end;
  end;
  Result := true;
end; { TContentProcessor.ProcessGenericCaption }

function TContentProcessor.ProcessImages(var line: string): boolean;
begin
  Result := true;
  repeat
    var match := FImageMatcher.Match(line);
    if not match.Success then
      break; //repeat

    var matchIndex := match.Index;
    var matchLength := match.Length;

    if matchIndex > 1 then begin
      var prefix := Copy(line, 1, matchIndex - 1);
      if IsMeta(prefix) then begin
        ProcessorState.LastMetaBookmark := Global.ContentWriter.CreateBookmark;
        ProcessorState.LastMetaBookmark.WriteLine(prefix);
      end
      else begin
        Global.ContentWriter.WriteLine(prefix);
        ProcessorState.LastMetaBookmark := nil;
      end;
      line := line.Remove(0, matchIndex - 1);
    end;

    var caption := match.Groups['caption'].Value;
    var bookmark := Global.ContentWriter.CreateBookmark;
    var imageCount := ProcessorState.Images.Add(bookmark,  match.Groups['imageref'].Value);
    var fileName := MakeImageFileName(imageCount, CImageExtPlaceholder);
    var anchor := Format(CImageAnchorTemplate, [imageCount + 1]);

    if not FilterCaption(caption, anchor) then
      Exit(false);

    for var outLine in ProcessorState.Format.Image(caption, fileName, anchor) do begin
      if not assigned(ProcessorState.LastMetaBookmark) then
        bookmark.WriteLine(outLine)
      else begin
        if IsMeta(outLine) then
          ProcessorState.LastMetaBookmark.Replace('}', ', ' + outLine.Remove(0, 1))
        else
          bookmark.WriteLine(outLine);
        ProcessorState.LastMetaBookmark := nil;
      end;
    end;

    line := line.Remove(0, matchLength);
  until false;
end; { TContentProcessor.ProcessImages }

function TContentProcessor.ProcessResource(const line: string): string;
begin
  Result := line;

  var match := FResourceMatcher.Match(line);
  if not match.Success then
    Exit;

  if not (match.Groups['reference'].Success and match.Groups['resource'].Success) then begin
    AddWarning('Unknown resource format: ' + line);
    Exit;
  end;

  var parts := match.Groups['resource'].Value.Split([' '], '"', '"', 1);
  if Length(parts) <> 1 then begin
    AddWarning('Unknown resource format: ' + line);
    Exit;
  end;

  if not WriteImage(match.Groups['reference'].Value, parts[0]) then
    Exit;

  Result := '';
end; { TContentProcessor.ProcessResource }

function TContentProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  while GetLine(line) do begin
    if line = '' then begin
      Global.ContentWriter.WriteLine('');
      continue; //while
    end;

    var tableMatch := FTableMatcher.Match(line);
    if tableMatch.Success then begin
      // Scrivener exporter generates {column-widths: 25%}|header 1|...| in one line
      if (tableMatch.Groups.Count > 1) and (tableMatch.Groups[1].Length > 0) then begin
        ProcessorState.LastMetaBookmark := Global.ContentWriter.CreateBookmark;
        ProcessorState.LastMetaBookmark.WriteLine(Copy(line, 1, tableMatch.Groups[1].Length));
        Delete(line, 1, tableMatch.Groups[1].Length);
      end;

      Global.ScrivenerReader.PushBack(line);
      nextState := State.Table;
      Exit(true);
    end;

    if line.StartsWith(CCodeBlock) then begin
      Global.ScrivenerReader.PushBack(line);
      nextState := State.Code;
      Exit(true);
    end;

    if line.StartsWith(CComment) then begin
      Global.ContentWriter.WriteLine(line);
      continue; //while
    end;

//    if not ProcessorState.Macros.Process(line) then
//      Exit(SetError(ProcessorState.Macros.ErrorMsg));

    if SwitchState(line, nextState) then
      Exit(true);

    if IsSection(line) then
      continue; //while

    if not ProcessImages(line) then
      Exit(false);

    line := ProcessResource(line);
    if line = '' then
      continue;

    RecordReferences(line);

    if not ProcessGenericCaption(line) then
      Exit(false);
    if line = '' then
      continue;

    ProcessCitations(line);

    if IsMeta(line) then begin
      ProcessorState.LastMetaBookmark := Global.ContentWriter.CreateBookmark;
      ProcessorState.LastMetaBookmark.WriteLine(line);
    end
    else begin
      Global.ContentWriter.WriteLine(line);
      ProcessorState.LastMetaBookmark := nil;
    end;

    ProcessorState.LastTableBookmark := nil;
  end;

  nextState := State.EOF;
  Result := true;
end; { TContentProcessor.Step }

function TContentProcessor.WriteImage(const imageRef, sourceFile: string): boolean;
var
  bookmark     : IBookmark;
  idxImage     : integer;
  realExtension: string;
  source       : string;
  target       : string;
begin
  if not ProcessorState.Images.Find(imageRef, bookmark, idxImage) then begin
    AddWarning('Image not found: ' + imageRef);
    Exit(false);
  end;

  realExtension := ExtractFileExt(sourceFile);
  try
    source := Global.ScrivenerFolder + sourceFile;
    target := IncludeTrailingPathDelimiter(Global.LeanpubManuscriptFolder
                                            + ProcessorState.Format.GetImagesFolder)
                  + MakeImageFileName(idxImage, realExtension);
    ForceDirectories(ExtractFilePath(target));
    TFile.Copy(source, target, true);
  except
    on E: Exception do begin
      AddWarning('Error copying %s to %s. %s.', [source, target, E.Message]);
      Exit(false);
    end;
  end;

  bookmark.Replace(CImageExtPlaceholder, realExtension);
  Result := true;
end; { TContentProcessor.WriteImage }

{ TCodeProcessor }

function TCodeProcessor.Step(var nextState: State): boolean;
var
  line: string;
begin
  if not (GetLine(line)
          and line.StartsWith(CCodeBlock))
  then
    Exit(SetError('Code block must start with ' + CCodeBlock));

  var meta := line.Remove(0, Length(CCodeBlock)).Trim;
  if meta.StartsWith('{') then begin
    var endMeta := Pos('}', meta);
    if endMeta > 0 then begin
      Global.ContentWriter.WriteLine(Copy(meta, 1, endMeta));
      Delete(meta, 1, endMeta);
      line := CCodeBlock + meta;
    end;
  end;

  Global.ContentWriter.WriteLine(CCodeBlock);
  line := line.Remove(0, Length(CCodeBlock));
  if line = '' then
    if not GetLine(line) then
      Exit(SetError('Unexpected end of file'));

  repeat
    if line.EndsWith(CCodeBlock) then begin
      if Length(line) > Length(CCodeBlock) then
        Global.ContentWriter.WriteLine(Copy(line, 1, Length(line) - Length(CCodeBlock)));
      Global.ContentWriter.WriteLine(CCodeBlock);
      nextState := State.Content;
      Exit(true);
    end;

    Global.ContentWriter.WriteLine(line);
    if not GetLine(line) then
      Exit(SetError('Unexpected end of file'));
  until false;

  nextState := State.EOF;
  Result := true;
end; { TCodeProcessor.Step }

{ TTableProcessor }

function TTableProcessor.Step(var nextState: State): boolean;
var
  line          : string;
  lines: TArray<string>;
  tableFormatter: ITableFormatter;
begin
  tableFormatter := CreateTableFormatter;

  ProcessorState.LastTableBookmark := Global.ContentWriter.CreateBookmark;

  while GetLine(line) do begin
    if not line.StartsWith('|') then begin
      Global.ScrivenerReader.PushBack(line);
      break; // while
    end;
    tableFormatter.Add(line);
  end;

  if not tableFormatter.Format(lines) then
    Exit(SetError('Malformed table'));

  Global.ContentWriter.WriteLine(lines);

// Alternative approach:
// {type: table, id: scriv4lean-table-tables-1}
// ![Table caption 1](tables\table1.txt)
// Needs macros to be implemented without too many complications.
// Maybe bookmarks would suffice?

  nextState := State.Content;
  Result := true;
end; { TTableProcessor.Step }

{ TTemplateProcessor }

function TTemplateProcessor.FillTemplate(template: TStrings;
  const mapper: TFunc<string, string>): TArray<string>;
begin
  var list := TStringList.Create;
  try
    for var line in template do
      list.Add(ReplaceAllTags(line, mapper));
    Result := list.ToStringArray;
  finally FreeAndNil(list); end;
end; { TTemplateProcessor.FillTemplate }

function TTemplateProcessor.ReplaceAllTags(const line: string;
  const mapper: TFunc<string, string>): string;
begin
  Result := line;

  var pTag := 1;
  repeat
    pTag := PosEx('@', Result, pTag);
    if pTag = 0 then
      Exit;

    var pEnd := PosEx('@', Result, pTag + 1);
    if pEnd = 0 then
      Exit;

    var tag := Copy(Result, pTag + 1, pEnd - pTag - 1);
    Delete(Result, pTag, pEnd - pTag + 1);
    var mapped := mapper(tag);
    Insert(mapped, Result, pTag);
    pTag := pTag + Length(mapped);
  until false;
end; { TTemplateProcessor.ReplaceAllTags }

{ TListOfProcessor }

procedure TListOfProcessor.AfterConstruction;
begin
  inherited;
  FBeginMarker := TRegEx.Create(CListOfMarker);
  FEndMarker := TRegEx.Create(CListOfEndMarker);
end; { TListOfProcessor.AfterConstruction }

function TListOfProcessor.ReplaceTag(const tag: string; const captionInfo: TCaptionInfo):
  string;
begin
  if SameText(tag, CTOFTagCaption) then
    Result := captionInfo.Caption
  else if SameText(tag, CTOFTagReference) then
    Result := captionInfo.Reference
  else
    Result := tag;
end; { TListOfProcessor.ReplaceTag }

function TListOfProcessor.Step(var nextState: State): boolean;
var
  tableName: string;
  trailer  : string;
begin
  var template := TStringList.Create;
  try
    if not ReadBlock(template, 'Table', FBeginMarker, FEndMarker, tableName, trailer) then
      Exit(false);

    for var captionInfo in ProcessorState.Captions do
      if SameText(tableName, captionInfo.TableName)
         and (captionInfo.Caption <> '')
      then
        Global.ContentWriter.WriteLine(
          FillTemplate(template,
            function (tag: string): string
            begin
              Result := ReplaceTag(tag, captionInfo);
            end));

    if trailer <> '' then
      Global.ContentWriter.WriteLine(trailer);

    nextState := State.Content;
    Result := true;
  finally FreeAndNil(template); end;
end; { TListOfProcessor.Step }

{ TBibProcessor }

procedure TBibProcessor.AfterConstruction;
begin
  inherited;
  FBeginMarker := TRegEx.Create(CBibMarker);
  FEndMarker := TRegEx.Create(CBibEndMarker);
end; { TBibProcessor.AfterConstruction }

function TBibProcessor.Step(var nextState: State): boolean;
var
  tableName: string;
  trailer  : string;
begin
  var template := TStringList.Create;
  try
    if not ReadBlock(template, 'Bibliography', FBeginMarker, FEndMarker, tableName, trailer) then
      Exit(false);

    if not assigned(Global.BibTeX) then
      Exit(SetError('BibTeX file was not specified'));

    Global.ContentWriter.WriteLine(
      Global.BibTeX.CreateBibliography(template.ToStringArray,
        optNumberCitations in ProcessorState.Options));

    if trailer <> '' then
      Global.ContentWriter.WriteLine(trailer);

    nextState := State.Content;
    Result := true;
  finally FreeAndNil(template); end;
end; { TBibProcessor.Step }

{ TPoetryProcessor }

procedure TPoetryProcessor.AfterConstruction;
begin
  inherited;
  FBeginMarker := TRegEx.Create(CPoetryMarker);
  FEndMarker := TRegEx.Create(CPoetryEndMarker);
end; { TPoetryProcessor.AfterConstruction }

function TPoetryProcessor.Step(var nextState: State): boolean;
var
  tableName: string;
  trailer  : string;
begin
  var template := TStringList.Create;
  try
    if not ReadBlock(template, 'Poetry', FBeginMarker, FEndMarker, tableName, trailer) then
      Exit(false);

    Global.ContentWriter.WriteLine(ProcessorState.Format.Poetry(template.ToStringArray));

    if trailer <> '' then
      Global.ContentWriter.WriteLine(trailer);

    nextState := State.Content;
    Result := true;
  finally FreeAndNil(template); end;
end; { TPoetryProcessor.Step }

{ TQuoteProcessor }

function TQuoteProcessor.Step(var nextState: State): boolean;
var
  endQuote  : string;
  line      : string;
  startQuote: string;
  tableName : string;
  trailer   : string;
begin
  if not GetLine(line) then
    Exit(SetError('Unexpected end of file'));

  if line.StartsWith(CBlockQuoteMarker) then begin
    startQuote := CBlockQuoteMarker;
    endQuote := CBlockQuoteEndMarker;
  end
  else if line.StartsWith(CAsideMarker) then begin
    startQuote := CAsideMarker;
    endQuote := CAsideEndMarker;
  end
  else if line.StartsWith(CBlurbMarker) then begin
    startQuote := CBlurbMarker;
    endQuote := CBlurbEndMarker;
  end
  else
    Exit(SetError('Unexpected block type: ' + line));

  Global.ScrivenerReader.PushBack(line);

  var quote := TStringList.Create;
  try
    if not ReadBlock(quote, 'Quote', TRegex.Create(startQuote), TRegex.Create(endQuote) , tableName, trailer) then
      Exit(false);

    if (quote.Count > 0) and IsMeta(quote[0]) then begin
      // combine extra attributes into block introduction command
      Insert(', ' + Copy(quote[0], 2, Length(quote[0]) - 2), startQuote, Length(startQuote));
      quote.Delete(0);
    end;
    Global.ContentWriter.WriteLine(startQuote);
    Global.ContentWriter.WriteLine(quote.ToStringArray);
    Global.ContentWriter.WriteLine(endQuote);
    if trailer <> '' then
      Global.ContentWriter.WriteLine(trailer);
  finally FreeAndNil(quote); end;

  nextState := State.Content;
  Result := true;
end; { TQuoteProcessor.Step }

{ TProcessor }

constructor TProcessor.Create(const global: IGlobal; const anchors: IAnchors;
  const context: IContext; const references: IReferences;
  const todoWriter: ITODOWriter; const images: IImages;
  const captions: ICaptions; const macros: IMacros; const format: IFormat;
  const notes: INotes);
begin
  inherited Create;
  FWarnings := TList<string>.Create;
  FProcessorState := CreateProcessorState;
  FProcessorState.Anchors    := anchors;
  FProcessorState.Context    := context;
  FProcessorState.References := references;
  FProcessorState.TODOWriter := todoWriter;
  FProcessorState.Images     := images;
  FProcessorState.Captions   := captions;
  FProcessorState.Macros     := macros;
  FProcessorState.Format     := format;
  FProcessorState.Notes      := notes;
  FProcessor[State.BOF]          := TBOFProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.EOF]          := TEOFProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Heading]      := THeadingProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Part]         := TPartProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Chapter]      := TChapterProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.FrontMatter]  := TFrontMatterProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.BackMatter]   := TBackMatterProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Content]      := TContentProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Code]         := TCodeProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Table]        := TTableProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.ListOf]       := TListOfProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Bibliography] := TBibProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Poetry]       := TPoetryProcessor.Create(global, FProcessorState, WarningCollector);
  FProcessor[State.Quote]        := TQuoteProcessor.Create(global, FProcessorState, WarningCollector);
  FGlobal := global;
end; { TProcessor.Create }

destructor TProcessor.Destroy;
begin
  FProcessorState.Macros := nil;
  FProcessorState := nil;

  FreeAndNil(FWarnings);
  inherited;
end; { TProcessor.Destroy }

function TProcessor.CheckReferences: boolean;
begin
  var errors := TList<string>.Create;
  try
    var reference := TPair<string,string>.Create('', ''); //workaround for a weird codegen bug in 10.3.1
    for reference in FProcessorState.References do
      if not FProcessorState.Anchors.Has(reference.Key) then
        errors.Add('Reference not found: ' + reference.Value);

    Result := errors.Count = 0;
    if not Result then
      SetError(string.Join(TPlatform.NewLineDelim, errors.ToArray));
  finally FreeAndNil(errors); end;
end; { TProcessor.CheckReferences }

function TProcessor.GetWarnings: TArray<string>;
begin
  Result := FWarnings.ToArray;
end; { TProcessor.GetWarnings }

procedure TProcessor.PostprocessAnchors;
begin
  FGlobal.ContentWriter.ForEachLine(
    procedure (var line, nextLine: string)
    begin
      if TStateProcessor.IsMeta(line) and TStateProcessor.IsMeta(nextLine)
         and (line[2] = '#') and (nextLine[2] <> '#')
      then begin
        Insert(', id: ' + Copy(line, 3, Length(line) - 3), nextLine, Length(nextLine));
        line := '';
      end;
    end);
end; { TProcessor.PostprocessAnchors }

procedure TProcessor.PostprocessFootEndNotes;
begin
  ProcessNotes(CFootnoteMarker, CFootnoteEndMarker,
    function: INote begin Result := FProcessorState.Notes.StartFootnote; end);
  ProcessNotes(CEndnoteMarker, CEndnoteEndMarker,
    function: INote begin Result := FProcessorState.Notes.StartEndnote; end);

  FGlobal.ContentWriter.WriteLine('');
  for var note in FProcessorState.Notes.All do begin
    var problems: TArray<string>;
    FGlobal.ContentWriter.WriteLine(FProcessorState.Macros.ApplyTo(note.Description, problems));
    FGlobal.ContentWriter.WriteLine('');
    for var problem in problems do
      WarningCollector(problem);
  end;
end; { TProcessor.PostprocessFootEndNotes }

procedure TProcessor.PostprocessMacros;
begin
  var problems: TArray<string>;
  FProcessorState.Macros.ApplyTo(FGlobal.ContentWriter, problems);
  for var problem in problems do
    WarningCollector(problem);
end; { TProcessor.PostprocessMacros }

procedure TProcessor.PostprocessQuotes;
begin
  FGlobal.ContentWriter.ForEachLine(
    function (const line: string): string
    begin
      if not TStateProcessor.IsMeta(line) then
        Result := line
      else
        Result := StringReplace(
                  StringReplace(line, '“', '"', [rfReplaceAll]),
                                      '”', '"', [rfReplaceAll]);
    end);
end; { TProcessor.PostprocessQuotes }

procedure TProcessor.ProcessNotes(const startMarker, endMarker: string;
  const noteFactory: TFunc<INote>);
begin
  var notes: TArray<IBookmark> := FGlobal.ContentWriter.MakeSegments(startMarker, endMarker, true);

  for var content in notes do begin
    var note := noteFactory();
    for var line in content.AllLines do
      note.Append(line);
    content.ReplaceAll([note.Marker + ' ']);
  end;

  for var bookmark in notes do begin
    FGlobal.ContentWriter.MergeWithPrevious(bookmark);
    FGlobal.ContentWriter.MergeWithNext(bookmark);
  end;
end; { TProcessor.ProcessNotes }

function TProcessor.Run(options: TProcessorOptions): boolean;
begin
  FProcessorState.Options := options;

  var processor := State.BOF;
  while processor <> State.EOF do
    if not FProcessor[processor].Step(processor) then
      Exit(SetError(FProcessor[processor].ErrorMsg));

  PostprocessFootEndNotes;
  PostprocessQuotes;

  FProcessorState.TODOWriter.Flush;
  FProcessorState.TODOWriter := nil;

  PostprocessMacros;
  PostprocessAnchors;

  Result := CheckReferences;
end; { TProcessor.Run }

procedure TProcessor.WarningCollector(message: string);
begin
  FWarnings.Add(message);
end; { TProcessor.WarningCollector }

end.
