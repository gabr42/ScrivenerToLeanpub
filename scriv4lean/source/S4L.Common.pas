unit S4L.Common;

interface

uses
  System.Classes;

function Asgn(var output: boolean; input: boolean): boolean;

implementation

function Asgn(var output: boolean; input: boolean): boolean;
begin
  output := input;
  Result := input;
end; { Asgn }

end.
