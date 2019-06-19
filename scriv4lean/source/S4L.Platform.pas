unit S4L.Platform;

interface

type
  TPlatform = class
  public
    class function NewLineDelim: string;
  end; { TPlatform }

implementation

{ TPlatform }

class function TPlatform.NewLineDelim: string;
begin
  {$IFDEF MSWindows}
  Result := #13#10;
  {$ELSE}
  Result := #10;
  {$ENDIF}
end; { TPlatform.NewLineDelim }

end.
