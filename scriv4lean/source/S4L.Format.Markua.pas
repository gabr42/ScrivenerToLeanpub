unit S4L.Format.Markua;

interface

uses
  S4L.Format;

function CreateMarkuaFormat: IFormat;

implementation

uses
  System.SysUtils;

type
  TMarkuaFormatter = class(TInterfacedObject, IFormat)
  public
    function Anchor(const name: string): string;
    function BookPartDelimiter(part: BookPart): TArray<string>;
    function CenteredCaption(const caption: string): TArray<string>;
    function Chapter(const name: string): string;
    function Endnote(const name: string): string;
    function Footnote(const name: string): string;
    function GetBookFileName: string;
    function GetImagesFolder: string;
    function HttpReference(const caption, anchor: string): string;
    function Image(const caption, fileName, anchor: string): TArray<string>;
    function ListIndent: string;
    function Part(const name: string): string;
    function Poetry(const lines: TArray<string>): TArray<string>;
    function Reference(const caption, anchor: string): string;
    function Section(const name: string; level: integer): string;
  end; { TMarkuaFormatter }

{ exports }

function CreateMarkuaFormat: IFormat;
begin
  Result := TMarkuaFormatter.Create;
end; { CreateMarkuaFormat }

{ TMarkuaFormatter }

function TMarkuaFormatter.Anchor(const name: string): string;
begin
  Result := '{#' + name + '}';
end; { TMarkuaFormatter.Anchor }

function TMarkuaFormatter.BookPartDelimiter(part: BookPart): TArray<string>;
begin
  case part of
    BookPart.FrontMatter: Result := ['', '{frontmatter}', ''];
    BookPart.MainMatter:  Result := ['', '{mainmatter}', ''];
    BookPart.BackMatter:  Result := ['', '{backmatter}', ''];
    else raise Exception.Create('Unknown book part');
  end;
end; { TMarkuaFormatter.BookPartDelimiter }

function TMarkuaFormatter.CenteredCaption(const caption: string): TArray<string>;
begin
  Result := [
    '{class: center}',
    'B> ' + caption
  ];
end; { TMarkuaFormatter.CenteredCaption }

function TMarkuaFormatter.Chapter(const name: string): string;
begin
  Result := '# ' + name;
end; { TMarkuaFormatter.Chapter }

function TMarkuaFormatter.Endnote(const name: string): string;
begin
  Result := '[^^' + name + ']';
end; { TMarkuaFormatter.Endnote }

function TMarkuaFormatter.Footnote(const name: string): string;
begin
  Result := '[^' + name + ']';
end; { TMarkuaFormatter.Footnote }

function TMarkuaFormatter.GetBookFileName: string;
begin
  Result := 'book.txt';
end; { TMarkuaFormatter.GetBookFileName }

function TMarkuaFormatter.GetImagesFolder: string;
begin
  Result := 'resources';
end; { TMarkuaFormatter.GetImagesFolder }

function TMarkuaFormatter.HttpReference(const caption, anchor: string): string;
begin
  Result := '[' + caption + '](' + anchor + ')';
end; { TMarkuaFormatter.HttpReference }

function TMarkuaFormatter.Image(const caption, fileName, anchor: string): TArray<string>;
begin
  Result := [
    Format('{title: "%s", id: %s}', [caption, anchor]),
    Format('![%s](%s)', [caption, fileName])
  ];
end; { TMarkuaFormatter.Image }

function TMarkuaFormatter.ListIndent: string;
begin
  Result := #9;
end; { TMarkuaFormatter.ListIndent }

function TMarkuaFormatter.Part(const name: string): string;
begin
  Result := '# ' + name + ' #';
end; { TMarkuaFormatter.Part }

function TMarkuaFormatter.Poetry(const lines: TArray<string>): TArray<string>;
begin
  Result := ['___'] + lines + ['___'];
end; { TMarkuaFormatter.Poetry }

function TMarkuaFormatter.Reference(const caption, anchor: string): string;
begin
  Result := '[' + caption + '](#' + anchor + ')';
end; { TMarkuaFormatter.Reference }

function TMarkuaFormatter.Section(const name: string; level: integer): string;
begin
  Result := string.Create('#', level) + ' ' + name;
end; { TMarkuaFormatter.Section }

end.
