unit S4L.Global;

interface

uses
  System.Classes,
  S4L.Reader, S4L.Writer, S4L.BibTeX;

type
  IGlobal = interface ['{5DD2FCB5-EF01-4612-88BA-48EAC0759EA0}']
    function  GetBibTeX: IBibTeX;
    function  GetContentWriter: IWriter;
    function  GetLeanpubManuscriptFolder: string;
    function  GetScrivenerFolder: string;
    function  GetScrivenerReader: IReader;
    procedure SetBibTeX(const value: IBibTeX);
    procedure SetContentWriter(const value: IWriter);
    procedure SetLeanpubManuscriptFolder(const value: string);
    procedure SetScrivenerFolder(const value: string);
    procedure SetScrivenerReader(const value: IReader);
  //
    property BibTeX: IBibTeX read GetBibTeX write SetBibTeX;
    property ContentWriter: IWriter read GetContentWriter write SetContentWriter;
    property LeanpubManuscriptFolder: string read GetLeanpubManuscriptFolder
      write SetLeanpubManuscriptFolder;
    property ScrivenerFolder: string read GetScrivenerFolder write SetScrivenerFolder;
    property ScrivenerReader: IReader read GetScrivenerReader
      write SetScrivenerReader;
  end; { IGlobal }

function CreateGlobal: IGlobal;

implementation

type
  TGlobal = class(TInterfacedObject, IGlobal)
  strict private
    FBibTeX                 : IBibTeX;
    FContentWriter          : IWriter;
    FLeanpubManuscriptFolder: string;
    FScrivenerFolder        : string;
    FScrivenerReader        : IReader;
  strict protected
    function  GetBibTeX: IBibTeX;
    function  GetContentWriter: IWriter;
    function  GetLeanpubManuscriptFolder: string;
    function  GetScrivenerFolder: string;
    function  GetScrivenerReader: IReader;
    procedure SetBibTeX(const value: IBibTeX);
    procedure SetContentWriter(const value: IWriter);
    procedure SetLeanpubManuscriptFolder(const value: string);
    procedure SetScrivenerFolder(const value: string);
    procedure SetScrivenerReader(const value: IReader);
  public
    property BibTeX: IBibTeX read GetBibTeX write SetBibTeX;
    property ContentWriter: IWriter read GetContentWriter write SetContentWriter;
    property LeanpubManuscriptFolder: string read GetLeanpubManuscriptFolder write
      SetLeanpubManuscriptFolder;
    property ScrivenerFolder: string read GetScrivenerFolder write SetScrivenerFolder;
    property ScrivenerReader: IReader read GetScrivenerReader write
        SetScrivenerReader;
  end; { TGlobal }

{ exports }

function CreateGlobal: IGlobal;
begin
  Result := TGlobal.Create;
end; { CreateGlobal }

{ TGlobal }

function TGlobal.GetBibTeX: IBibTeX;
begin
  Result := FBibTeX;
end; { TGlobal.GetBibTeX }

function TGlobal.GetContentWriter: IWriter;
begin
  Result := FContentWriter;
end; { TGlobal.GetContentWriter }

function TGlobal.GetLeanpubManuscriptFolder: string;
begin
  Result := FLeanpubManuscriptFolder;
end; { TGlobal.GetLeanpubManuscriptFolder }

function TGlobal.GetScrivenerFolder: string;
begin
  Result := FScrivenerFolder;
end;

function TGlobal.GetScrivenerReader: IReader;
begin
  Result := FScrivenerReader;
end; { TGlobal.GetScrivenerReader }

procedure TGlobal.SetBibTeX(const value: IBibTeX);
begin
  FBibTeX := value;
end; { TGlobal.SetBibTeX }

procedure TGlobal.SetContentWriter(const value: IWriter);
begin
  FContentWriter := value;
end; { TGlobal.SetContentWriter }

procedure TGlobal.SetLeanpubManuscriptFolder(const value: string);
begin
  FLeanpubManuscriptFolder := value;
end; { TGlobal.SetLeanpubManuscriptFolder }

procedure TGlobal.SetScrivenerFolder(const value: string);
begin
  FScrivenerFolder := value;
end;

procedure TGlobal.SetScrivenerReader(const value: IReader);
begin
  FScrivenerReader := value;
end; { TGlobal.SetScrivenerReader }

end.
