unit S4L.Images;

interface

uses
  S4L.Writer;

type
  IImages = interface ['{EB876DD8-729E-4A13-ACCC-B06E3221D2C4}']
    function Add(const bookmark: IBookmark; const imageRef: string): integer;
    function Find(const imageRef: string; var bookmark: IBookmark; var idxImage: integer): boolean;
  end; { IImages }

function CreateImages: IImages;

implementation

uses
  System.SysUtils, System.Generics.Collections;

type
  TImageInfo = TPair<IBookmark, string>;

  TImages = class(TInterfacedObject, IImages)
  strict private
    FImageList  : TList<TImageInfo>;
    FImageLookup: TDictionary<string, integer>;
  public
    constructor Create;
    destructor  Destroy; override;
    function  Add(const bookmark: IBookmark; const imageRef: string): integer;
    function  Find(const imageRef: string; var bookmark: IBookmark; var idxImage: integer): boolean;
  end; { TImages }

{ exports }

function CreateImages: IImages;
begin
  Result := TImages.Create;
end; { CreateImages }

{ TImages }

constructor TImages.Create;
begin
  inherited Create;
  FImageList := TList<TImageInfo>.Create;
  FImageLookup := TDictionary<string, integer>.Create;
end; { TImages.Create }

destructor TImages.Destroy;
begin
  FreeAndNil(FImageList);
  FreeAndNil(FImageLookup);
  inherited Destroy;
end; { TImages.Destroy }

function TImages.Add(const bookmark: IBookmark; const imageRef: string): integer;
begin
  Result := FImageList.Add(TImageInfo.Create(bookmark, imageRef));
  FImageLookup.Add(imageRef, Result);
end; { TImages.Add }

function TImages.Find(const imageRef: string; var bookmark: IBookmark;
  var idxImage: integer): boolean;
begin
  Result := FImageLookup.TryGetValue(imageRef, idxImage);
  if Result then
    bookmark := FImageList[idxImage].Key;
end; { TImages.Find }

end.
