unit S4L.Processor.State;

interface

uses
  S4L.Anchors, S4L.Context, S4L.Images, S4L.References,
  S4L.Writer, S4L.TODOWriter, S4L.Captions, S4L.Format, S4L.Macros, S4L.Notes,
  S4L.Processor.Config;

type
  {$SCOPEDENUMS ON}
  State       = (BOF, EOF, Heading, Part, Chapter, FrontMatter, BackMatter,
                 Content, Code, Table, ListOf, Bibliography, Poetry, Quote);
  ContentMode = (BOF, FrontMatter, MainMatter, BackMatter);
  {$SCOPEDENUMS OFF}

  IProcessorState = interface  ['{B6B5A709-7540-4E33-B2BF-0D5B37B28D1E}']
    function  GetAnchors: IAnchors;
    function  GetCaptions: ICaptions;
    function  GetChapterCount: integer;
    function  GetContent: ContentMode;
    function  GetContext: IContext;
    function  GetFormat: IFormat;
    function  GetImages: IImages;
    function  GetLastPartBookmark: IBookmark;
    function  GetLastTableBookmark: IBookmark;
    function  GetLastMetaBookmark: IBookmark;
    function  GetMacros: IMacros;
    function  GetNotes: INotes;
    function GetOptions: TProcessorOptions;
    function  GetPartCount: integer;
    function  GetReferences: IReferences;
    function  GetTODOWriter: ITODOWriter;
    procedure SetAnchors(const value: IAnchors);
    procedure SetCaptions(const value: ICaptions);
    procedure SetChapterCount(const value: integer);
    procedure SetContent(const value: ContentMode);
    procedure SetContext(const value: IContext);
    procedure SetFormat(const value: IFormat);
    procedure SetImages(const value: IImages);
    procedure SetLastPartBookmark(const value: IBookmark);
    procedure SetLastTableBookmark(const value: IBookmark);
    procedure SetLastMetaBookmark(const value: IBookmark);
    procedure SetMacros(const value: IMacros);
    procedure SetNotes(const value: INotes);
    procedure SetOptions(const value: TProcessorOptions);
    procedure SetPartCount(const value: integer);
    procedure SetReferences(const value: IReferences);
    procedure SetTODOWriter(const value: ITODOWriter);
  //
    property Anchors: IAnchors read GetAnchors write SetAnchors;
    property Captions: ICaptions read GetCaptions write SetCaptions;
    property ChapterCount: integer read GetChapterCount write SetChapterCount;
    property Content: ContentMode read GetContent write SetContent;
    property Context: IContext read GetContext write SetContext;
    property Format: IFormat read GetFormat write SetFormat;
    property Images: IImages read GetImages write SetImages;
    property LastMetaBookmark: IBookmark read GetLastMetaBookmark write SetLastMetaBookmark;
    property LastPartBookmark: IBookmark read GetLastPartBookmark write SetLastPartBookmark;
    property LastTableBookmark: IBookmark read GetLastTableBookmark write SetLastTableBookmark;
    property Macros: IMacros read GetMacros write SetMacros;
    property Notes: INotes read GetNotes write SetNotes;
    property Options: TProcessorOptions read GetOptions write SetOptions;
    property PartCount: integer read GetPartCount write SetPartCount;
    property References: IReferences read GetReferences write SetReferences;
    property TODOWriter: ITODOWriter read GetTODOWriter write SetTODOWriter;
  end; { IProcessorState }

function CreateProcessorState: IProcessorState;

implementation

type
  TProcessorState = class(TInterfacedObject, IProcessorState)
  strict private
    FAnchors          : IAnchors;
    FCaptions         : ICaptions;
    FChapterCount     : integer;
    FContent          : ContentMode;
    FContext          : IContext;
    FFormat           : IFormat;
    FImages           : IImages;
    FLastPartBookmark : IBookmark;
    FLastTableBookmark: IBookmark;
    FLastMetaBookmark : IBookmark;
    FMacros           : IMacros;
    FNotes            : INotes;
    FOptions          : TProcessorOptions;
    FPartCount        : integer;
    FReferences       : IReferences;
    FTODOWriter       : ITODOWriter;
  strict protected
    function  GetAnchors: IAnchors;
    function  GetCaptions: ICaptions;
    function  GetChapterCount: integer;
    function  GetContent: ContentMode;
    function  GetContext: IContext;
    function  GetFormat: IFormat;
    function  GetImages: IImages;
    function  GetLastPartBookmark: IBookmark;
    function  GetLastTableBookmark: IBookmark;
    function  GetLastMetaBookmark: IBookmark;
    function  GetMacros: IMacros;
    function  GetNotes: INotes;
    function  GetOptions: TProcessorOptions;
    function  GetPartCount: integer;
    function  GetReferences: IReferences;
    function  GetTODOWriter: ITODOWriter;
    procedure SetAnchors(const value: IAnchors);
    procedure SetCaptions(const value: ICaptions);
    procedure SetChapterCount(const value: integer);
    procedure SetContent(const value: ContentMode);
    procedure SetContext(const value: IContext);
    procedure SetFormat(const value: IFormat);
    procedure SetImages(const value: IImages);
    procedure SetLastPartBookmark(const value: IBookmark);
    procedure SetLastTableBookmark(const value: IBookmark);
    procedure SetLastMetaBookmark(const value: IBookmark);
    procedure SetMacros(const value: IMacros);
    procedure SetNotes(const value: INotes);
    procedure SetOptions(const value: TProcessorOptions);
    procedure SetPartCount(const value: integer);
    procedure SetReferences(const value: IReferences);
    procedure SetTODOWriter(const value: ITODOWriter);
  public
    property Anchors: IAnchors read GetAnchors write SetAnchors;
    property Captions: ICaptions read GetCaptions write SetCaptions;
    property ChapterCount: integer read GetChapterCount write SetChapterCount;
    property Content: ContentMode read GetContent write SetContent;
    property Context: IContext read GetContext write SetContext;
    property Format: IFormat read GetFormat write SetFormat;
    property Images: IImages read GetImages write SetImages;
    property LastMetaBookmark: IBookmark read GetLastMetaBookmark write SetLastMetaBookmark;
    property LastPartBookmark: IBookmark read GetLastPartBookmark write SetLastPartBookmark;
    property LastTableBookmark: IBookmark read GetLastTableBookmark write SetLastTableBookmark;
    property Macros: IMacros read GetMacros write SetMacros;
    property Notes: INotes read GetNotes write SetNotes;
    property Options: TProcessorOptions read GetOptions write SetOptions;
    property PartCount: integer read GetPartCount write SetPartCount;
    property References: IReferences read GetReferences write SetReferences;
    property TODOWriter: ITODOWriter read GetTODOWriter write SetTODOWriter;
  end; { TProcessorState }

{ externals }

function CreateProcessorState: IProcessorState;
begin
  Result := TProcessorState.Create;
end; { CreateProcessorState }

{ TProcessorState }

function TProcessorState.GetAnchors: IAnchors;
begin
  Result := FAnchors;
end; { TProcessorState.GetAnchors }

function TProcessorState.GetCaptions: ICaptions;
begin
  Result := FCaptions;
end; { TProcessorState.GetCaptions }

function TProcessorState.GetChapterCount: integer;
begin
  Result := FChapterCount;
end; { TProcessorState.GetChapterCount }

function TProcessorState.GetContent: ContentMode;
begin
  Result := FContent;
end; { TProcessorState.GetContent }

function TProcessorState.GetContext: IContext;
begin
  Result := FContext;
end; { TProcessorState.GetContext }

function TProcessorState.GetFormat: IFormat;
begin
  Result := FFormat;
end; { TProcessorState.GetFormat }

function TProcessorState.GetImages: IImages;
begin
  Result := FImages;
end; { TProcessorState.GetImages }

function TProcessorState.GetLastPartBookmark: IBookmark;
begin
  Result := FLastPartBookmark;
end; { TProcessorState.GetLastPartBookmark }

function TProcessorState.GetLastTableBookmark: IBookmark;
begin
  Result := FLastTableBookmark;
end;

function TProcessorState.GetLastMetaBookmark: IBookmark;
begin
  Result := FLastMetaBookmark;
end; { TProcessorState.GetLastMetaBookmark }

function TProcessorState.GetMacros: IMacros;
begin
  Result := FMacros;
end; { TProcessorState.GetMacros }

function TProcessorState.GetNotes: INotes;
begin
  Result := FNotes;
end; { TProcessorState.GetNotes }

function TProcessorState.GetOptions: TProcessorOptions;
begin
  Result := FOptions;
end; { TProcessorState.GetOptions }

function TProcessorState.GetPartCount: integer;
begin
  Result := FPartCount;
end; { TProcessorState.GetPartCount }

function TProcessorState.GetReferences: IReferences;
begin
  Result := FReferences;
end; { TProcessorState.GetReferences }

function TProcessorState.GetTODOWriter: ITODOWriter;
begin
  Result := FTODOWriter;
end; { TProcessorState.GetTODOWriter }

procedure TProcessorState.SetAnchors(const value: IAnchors);
begin
  FAnchors := value;
end; { TProcessorState.SetAnchors }

procedure TProcessorState.SetCaptions(const value: ICaptions);
begin
  FCaptions := value;
end; { TProcessorState.SetCaptions }

procedure TProcessorState.SetChapterCount(const value: integer);
begin
  FChapterCount := value;
end; { TProcessorState.SetChapterCount }

procedure TProcessorState.SetContent(const value: ContentMode);
begin
  FContent := value;
end; { TProcessorState.SetContent }

procedure TProcessorState.SetContext(const value: IContext);
begin
  FContext := value;
end; { TProcessorState.SetContext }

procedure TProcessorState.SetFormat(const value: IFormat);
begin
  FFormat := value;
end; { TProcessorState.SetFormat }

procedure TProcessorState.SetImages(const value: IImages);
begin
  FImages := value;
end; { TProcessorState.SetImages }

procedure TProcessorState.SetLastPartBookmark(const value: IBookmark);
begin
  FLastPartBookmark := value;
end; { TProcessorState.SetLastPartBookmark }

procedure TProcessorState.SetLastTableBookmark(const value: IBookmark);
begin
  FLastTableBookmark := value;
end;

procedure TProcessorState.SetLastMetaBookmark(const value: IBookmark);
begin
  FLastMetaBookmark := value;
end; { TProcessorState.SetLastMetaBookmark }

procedure TProcessorState.SetMacros(const value: IMacros);
begin
  FMacros := value;
end; { TProcessorState.SetMacros }

procedure TProcessorState.SetNotes(const value: INotes);
begin
  FNotes := value;
end; { TProcessorState.SetNotes }

procedure TProcessorState.SetOptions(const value: TProcessorOptions);
begin
  FOptions := value;
end; { TProcessorState.SetOptions }

procedure TProcessorState.SetPartCount(const value: integer);
begin
  FPartCount := value;
end; { TProcessorState.SetPartCount }

procedure TProcessorState.SetReferences(const value: IReferences);
begin
  FReferences := value;
end; { TProcessorState.SetReferences }

procedure TProcessorState.SetTODOWriter(const value: ITODOWriter);
begin
  FTODOWriter := value;
end; { TProcessorState.SetTODOWriter }

end.
