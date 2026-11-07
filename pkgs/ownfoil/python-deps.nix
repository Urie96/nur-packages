# Python dependencies of ownfoil that nixpkgs does not provide (nstools) or
# provides in an older version than the one ownfoil pins (nsz 5.0.0).
{ lib, python3, fetchPypi }:

python3.override {
  packageOverrides =
    _final: prev: {
      nsz = (prev.nsz.override { withGUI = false; }).overridePythonAttrs (old: rec {
        version = "5.0.0";

        src = fetchPypi {
          pname = "nsz";
          inherit version;
          hash = "sha256-3K2gLoDwZyGmTE19vX10rlac22UCvmNPTqFv+wb6ies=";
        };

        # 5.0.0 is only published on PyPI, it still ships a plain setup.py.
        format = "setuptools";

        meta = old.meta // {
          changelog = "https://github.com/nicoboss/nsz/releases/tag/${version}";
        };
      });

      nstools = prev.buildPythonPackage rec {
        pname = "nstools";
        version = "2.0.0b7";
        format = "setuptools";

        src = fetchPypi {
          inherit pname version;
          hash = "sha256-+/QIO31u80bLg9yUxezpNH3keOWKt1jsL2HnMNuwJSQ=";
        };

        propagatedBuildInputs = with prev; [
          enlighten
          pycryptodome
          requests
          zstandard
        ];

        # The test suite needs a Switch keys file, which cannot be distributed.
        doCheck = false;

        meta = {
          description = "Nintendo Switch NSP/XCI/CIA verification tools";
          homepage = "https://github.com/seiya-dev/NSTools";
          license = lib.licenses.mit;
        };
      };
    };
}
