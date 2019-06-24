unit S4L.BibTeX;

interface

uses
  S4L.Errors, S4L.Format;

type
  IBibTeX = interface(IErrorBase) ['{8C6FC76A-8E53-460C-9D58-D8CD84882DD9}']
    function  CreateBibliography(const template: TArray<string>;
      orderByAppearance: boolean): TArray<string>;
    function  GetCitationNumber(const citationKey: string): integer;
    function  GetCitationURL(const citationKey: string): string;
    function  HasCitation(const citationKey: string; var citationAnchor: string): boolean;
    function  Read(const fileName: string): boolean;
  end; { IBibTeX }

function CreateBibTeX(const format: IFormat): IBibTeX;

implementation

uses
  System.SysUtils, System.Classes, System.Math, System.StrUtils,
  System.RegularExpressions,
  System.Generics.Defaults, System.Generics.Collections,
  S4L.Reader;

type
  TBibTeXItem = class
  strict private
    FAppearanceIndex: integer;
    FCitationKey    : string;
    FIsUsed         : boolean;
    FItemType       : string;
    FTags           : TDictionary<string, string>;
  strict protected
    function GetCitationKey: string;
    function GetTags: TDictionary<string, string>;
    function GetItemType: string;
  public
    constructor Create(const AItemType, ACitationKey: string; ATags: TDictionary<string, string>);
    destructor  Destroy; override;
    property AppearanceIndex: integer read FAppearanceIndex write FAppearanceIndex;
    property CitationKey: string read GetCitationKey;
    property IsUsed: boolean read FIsUsed write FIsUsed;
    property ItemType: string read GetItemType;
    property Tags: TDictionary<string, string> read GetTags;
  end; { TBibTeXItem }

  TBibTeX = class(TErrorBase, IBibTeX)
  strict private const
    CURLTag = 'url';
  var
    FCitationOrder     : TStringList;
    FConditionalMatcher: TRegEx;
    FFormat            : IFormat;
    FItems             : TObjectList<TBibTeXItem>;
    FReader            : IReader;
    FTagMatcher        : TRegEx;
  strict protected
    function  AllTagsHaveValues(const tags: TMatchCollection; const item: TBibTeXItem):
      boolean;
    function  ApplyTemplate(const item: TBibTeXItem;
      const template: TArray<string>; useAppearanceIndex: boolean): TArray<string>;
    function  Cleanup(const value: string): string;
    function  FillTemplate(templates: TDictionary<string, TArray<string>>;
      orderByUseIndex: boolean): TArray<string>;
    function  FilterConditionals(const line: string; const item: TBibTeXItem): string;
    function  ItemKeys: TArray<string>;
    function  MakeAnchor(const citationKey: string): string;
    function  ParseTemplate(const template: TArray<string>;
      templates: TDictionary<string, TArray<string>>): boolean;
    function  ReadItem: boolean;
    procedure SkipPreamble;
  public
    constructor Create(const format: IFormat);
    destructor  Destroy; override;
    function  CreateBibliography(const template: TArray<string>;
      orderByUseIndex: boolean): TArray<string>;
    function  GetCitationNumber(const citationKey: string): integer;
    function  GetCitationURL(const citationKey: string): string;
    function  HasCitation(const citationKey: string; var citationAnchor: string): boolean;
    function  Read(const fileName: string): boolean;
  end; { TBibTeX }

{ exports }

function CreateBibTeX(const format: IFormat): IBibTeX;
begin
  Result := TBibTeX.Create(format);
end; { CreateBibTeX }

{ TBibTeX }

constructor TBibTeX.Create(const format: IFormat);
begin
  inherited Create;
  FFormat := format;
  FItems := TObjectList<TBibTeXItem>.Create;
  FCitationOrder := TStringList.Create;
  FConditionalMatcher := TRegEx.Create('\[.*?@.*?@.*?\]');
  FTagMatcher := TRegEx.Create('@.*?@');
end; { TBibTeX.Create }

destructor TBibTeX.Destroy;
begin
  FreeAndNil(FCitationOrder);
  FreeAndNil(FItems);
  inherited;
end; { TBibTeX.Destroy }

function TBibTeX.AllTagsHaveValues(const tags: TMatchCollection;
  const item: TBibTeXItem): boolean;
var
  value: string;
begin
  for var tag: TMatch in tags do
    if not (item.Tags.TryGetValue(tag.Value.Trim(['@']), value) and (value <> '')) then
      Exit(false);

  Result := true;
end; { TBibTeX.AllTagsHaveValues }

function TBibTeX.ApplyTemplate(const item: TBibTeXItem;
  const template: TArray<string>; useAppearanceIndex: boolean): TArray<string>;
var
  kv: TPair<string, string>;
begin
  var output := TStringList.Create;
  try
    for var templLine in template do begin
      var line := FilterConditionals(templLine, item);
      if Pos('@citationKey@', line) > 0 then
        line := StringReplace(line, '@citationKey@',
                  '[' + IfThen(useAppearanceIndex, item.AppearanceIndex.ToString, item.CitationKey) + ']',
                  [rfReplaceAll])
               + FFormat.Anchor(MakeAnchor(item.CitationKey));
      for kv in item.Tags do
        line := StringReplace(line, '@' + kv.Key + '@', kv.Value, [rfReplaceAll]);
      output.Add(line);
    end;
    Result := output.ToStringArray;
  finally FreeAndNil(output); end;
end; { TBibTeX.ApplyTemplate }

function TBibTeX.Cleanup(const value: string): string;
begin
  Result := StringReplace(
            StringReplace(
            StringReplace(value, '{\v{c}}', 'č', [rfReplaceAll]),
                                 '{\v{s}}', 'š', [rfReplaceAll]),
                                 '{\v{z}}', 'ž', [rfReplaceAll]);
end; { TBibTeX.Cleanup }

function TBibTeX.CreateBibliography(const template: TArray<string>;
  orderByUseIndex: boolean): TArray<string>;
var
  templates: TDictionary<string, TArray<string>>;
begin
  templates := TDictionary<string, TArray<string>>.Create(
    TOrdinalIStringComparer(TIStringComparer.Ordinal));
  try
    if not ParseTemplate(template, templates) then
      Exit;

    Result := FillTemplate(templates, orderByUseIndex);
  finally FreeAndNil(templates); end;
end; { TBibTeX.CreateBibliography }

function TBibTeX.FillTemplate(templates: TDictionary<string, TArray<string>>;
  orderByUseIndex: boolean): TArray<string>;
begin
  var output := TStringList.Create;
  try
    if orderByUseIndex then begin
      for var item in FItems do
        item.AppearanceIndex := FCitationOrder.IndexOf(item.CitationKey) + 1;
      FItems.Sort(
        TComparer<TBibTeXItem>.Construct(
          function (const left, right: TBibTeXItem): integer
          begin
            Result := CompareValue(left.AppearanceIndex, right.AppearanceIndex);
          end));
    end
    else
      FItems.Sort(
        TComparer<TBibTeXItem>.Construct(
          function (const left, right: TBibTeXItem): integer
          begin
            Result := TOrdinalIStringComparer(TIStringComparer.Ordinal).Compare(left.CitationKey, right.CitationKey);
          end));

    for var item in FItems do begin
      var template: TArray<string>;
      if templates.TryGetValue(item.ItemType, template) then
        if item.IsUsed then
          output.AddStrings(ApplyTemplate(item, template, orderByUseIndex));
    end;
    Result := output.ToStringArray;
  finally FreeAndNil(output); end;
end; { TBibTeX.FillTemplate }

function TBibTeX.FilterConditionals(const line: string; const item: TBibTeXItem): string;
begin
  Result := line;
  var startPos := 1;
  repeat
    var match := FConditionalMatcher.Match(Result, startPos);
    if not match.Success then
      break; //repeat

    var tags := FTagMatcher.Matches(match.Value);
    if not AllTagsHaveValues(tags, item) then
      Delete(Result, match.Index, match.Length)
    else begin
      Delete(Result, match.Index, 1);
      startPos := match.Index + match.Length - 2;
      Delete(Result, startPos, 1);
    end;
  until false;
end; { BibTeX.FilterConditionals }

function TBibTeX.GetCitationNumber(const citationKey: string): integer;
begin
  Result := FCitationOrder.IndexOf(citationKey);
  if Result < 0 then
    Result := FCitationOrder.Add(citationKey);
  Inc(Result);
end; { BibTeX.GetCitationNumber }

function TBibTeX.GetCitationURL(const citationKey: string): string;
begin
  Result := '';
  for var item in FItems do
    if SameText(item.CitationKey, citationKey) then begin
      item.Tags.TryGetValue(CURLTag, Result);
      Exit;
    end;
end; {BibTeX.GetCitationURL }

function TBibTeX.HasCitation(const citationKey: string;
  var citationAnchor: string): boolean;
begin
  Result := false;
  for var item in FItems do
    if SameText(item.CitationKey, citationKey) then begin
      item.IsUsed := true;
      citationAnchor := MakeAnchor(citationKey);
      Exit(true);
    end;
end; { TBibTeX.HasCitation }

function TBibTeX.ItemKeys: TArray<string>;
begin                                      
  var keys := TStringList.Create;
  try
    for var item in FItems do
      keys.Add(item.CitationKey);
    keys.Sort;
    Result := keys.ToStringArray;
  finally FreeAndNil(keys); end;
end; { TBibTeX.ItemKeys }

function TBibTeX.MakeAnchor(const citationKey: string): string;
begin
  Result := 'scriv4lean-biblio-' + citationKey;
end; { TBibTeX.MakeAnchor }

function TBibTeX.ParseTemplate(const template: TArray<string>;
  templates: TDictionary<string, TArray<string>>): boolean;
begin
  var templateStart := TRegEx.Create('^([A-Za-z]+)=(.*)$');
  var itemType: string := '';
  var currTemplate := TStringList.Create;
  try
    for var line in template do begin
      var match := templateStart.Match(line);
      if match.Success then begin
        if itemType <> '' then begin
          templates.Add(itemType, currTemplate.ToStringArray);
          currTemplate.Clear;
        end;
        itemType := match.Groups[1].Value;
        if match.Groups[2].Value <> '' then
          currTemplate.Add(match.Groups[2].Value);
      end
      else begin
        if line = '.' then
          currTemplate.Add('')
        else
          currTemplate.Add(line);
      end;
    end;
    if itemType <> '' then
      templates.Add(itemType, currTemplate.ToStringArray);
  finally FreeAndNil(currTemplate); end;

  Result := true;
end; { TBibTeX.ParseTemplate }

function TBibTeX.Read(const fileName: string): boolean;
var
  errMsg: string;
begin
  FReader := CreateReader(fileName, errMsg);
  if not assigned(FReader) then
    Exit(SetError(errMsg));

  SkipPreamble;

  while ReadItem do
    ;

  Result := (ErrorMsg = '');
end; { TBibTeX.Read }

function TBibTeX.ReadItem: boolean;
var
  line: string;
begin
  if not FReader.GetLine(line) then
    Exit(false);

  var intro: TArray<string> := line.TrimLeft(['@']).TrimRight([',']).Split(['{']);
  if not (line.StartsWith('@') and line.EndsWith(',') and line.Contains('{') and (Length(intro) = 2)) then
    Exit(SetError('Invalid format: ' + line));

  var tags := TDictionary<string, string>.Create;
  try
    repeat
      if not FReader.GetLine(line) then
        Exit(SetError('Unexpected end of file'));

      if line.StartsWith('}') then
        break; //repeat

      var tagData := line.TrimRight([',']).Split(['=']);
      if Length(tagData) <> 2 then
        Exit(SetError('Invalid format: ' + line));

      var tagValue := tagData[1].Trim;
      if (tagValue.StartsWith('{') and tagValue.EndsWith('}'))
         or (tagValue.StartsWith('"') and tagValue.EndsWith('"'))
      then
        tagValue := Copy(tagValue, 2, Length(tagValue) - 2);
      if (tagValue.StartsWith('{') and tagValue.EndsWith('}')) then
        tagValue := Copy(tagValue, 2, Length(tagValue) - 2);
      tags.Add(tagData[0].Trim, Cleanup(tagValue));
    until false;

    FItems.Add(TBibTeXItem.Create(intro[0], intro[1], tags));
    tags := nil; //FItems takes ownership
  finally FreeAndNil(tags); end;

  Result := true;
end; { TBibTeX.ReadItem }

procedure TBibTeX.SkipPreamble;
var
  line: string;
begin
  while FReader.GetLine(line) do
    if line.StartsWith('@') then begin
      FReader.PushBack(line);
      Exit
    end;
end; { TBibTeX.SkipPreamble }

constructor TBibTeXItem.Create(const AItemType, ACitationKey: string;
  ATags: TDictionary<string, string>);
begin
  inherited Create;
  FItemType := AItemType;
  FCitationKey := ACitationKey;
  FTags := ATags; // takes ownership
end; { TBibTeXItem.Create }

destructor TBibTeXItem.Destroy;
begin
  FreeAndNil(FTags);
  inherited;
end; { TBibTeXItem.Destroy }

function TBibTeXItem.GetCitationKey: string;
begin
  Result := FCitationKey;
end; { TBibTeXItem.GetCitationKey }

function TBibTeXItem.GetTags: TDictionary<string, string>;
begin
  Result := FTags;
end; { TBibTeXItem.GetTags }

function TBibTeXItem.GetItemType: string;
begin
  Result := FItemType;
end; { TBibTeXItem.GetItemType }

end.
