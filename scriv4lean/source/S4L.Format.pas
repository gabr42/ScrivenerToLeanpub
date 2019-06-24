unit S4L.Format;

interface

type
  {$SCOPEDENUMS ON}
  BookPart = (FrontMatter, MainMatter, BackMatter);
  {$SCOPEDENUMS OFF}

  IFormat = interface ['{87EFFA62-380B-45BF-8479-6F7052569848}']
    function Anchor(const name: string; const attributes: string = ''): string;
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
  end; { IFormat }

implementation

end.
