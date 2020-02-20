with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "luaradio";
  LUA_CPATH = "${pkgs.rtl-sdr}/lib/?.so";
  LUA_PATH = "./?.lua";
  shellHook = ''
source hook.sh
  '';
  nativeBuildInputs = with pkgs; [ luajit rtl-sdr gnuplot sox ];
}
