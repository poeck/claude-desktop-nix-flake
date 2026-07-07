{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  asar,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libayatana-appindicator,
  libcap_ng,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libseccomp,
  libuuid,
  libva,
  libxkbcommon,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  mesa,
  nspr,
  nss,
  OVMF,
  pango,
  perl,
  qemu,
  systemd,
  trash-cli,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  sources = {
    x86_64-linux = {
      debArch = "amd64";
      hash = "sha256-Vvpd4FPgpo3HWDZ3hXvtz0IZsZ2QIBQA4CN7fXTVEvE=";
    };
    aarch64-linux = {
      debArch = "arm64";
      hash = "sha256-OMZaEibczHWmskGLnUwGT0+dxTMfiWCK7dVU2H1Sm6M=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "claude-desktop is not packaged for ${stdenv.hostPlatform.system}");

  firmwareCodePath =
    if stdenv.hostPlatform.isAarch64 then
      "${qemu}/share/qemu/edk2-aarch64-code.fd"
    else
      "${OVMF.fd}/FV/OVMF_CODE.fd";

  runtimeLibs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libayatana-appindicator
    libcap_ng
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libseccomp
    libuuid
    libva
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    wayland
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
  ];

  runtimeBins = [
    glib
    qemu
    trash-cli
    xdg-utils
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop";
  version = "1.18286.2";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_${source.debArch}.deb";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    dpkg
    asar
    autoPatchelfHook
    makeWrapper
    perl
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --extract --file - --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/share"
    cp -a usr/lib/claude-desktop "$out/lib/"
    cp -a usr/share/applications usr/share/icons usr/share/doc "$out/share/"

    substituteInPlace "$out/share/applications/claude-desktop.desktop" \
      --replace-fail "Exec=claude-desktop" "Exec=$out/bin/claude-desktop"

    asarRoot="$(mktemp -d)"
    asar extract "$out/lib/claude-desktop/resources/app.asar" "$asarRoot"

    FIRMWARE_CODE_PATH="${firmwareCodePath}" \
    VIRTIOFSD_PATH="$out/lib/claude-desktop/resources/virtiofsd" \
    perl -0pi -e '
      s{([A-Za-z0-9_\$]+)=process\.arch==="arm64"\?\["/usr/share/AAVMF/AAVMF_CODE\.fd"\]:\["/usr/share/OVMF/OVMF_CODE_4M\.fd","/usr/share/OVMF/OVMF_CODE\.fd"\]}{$1=["$ENV{FIRMWARE_CODE_PATH}"]} or die "failed to patch firmware path\n";
      s{([A-Za-z0-9_\$]+)=\["/usr/libexec/virtiofsd","/usr/bin/virtiofsd"\]}{$1=["$ENV{VIRTIOFSD_PATH}"]} or die "failed to patch virtiofsd path\n";
      s{return A\.replace\("OVMF_CODE","OVMF_VARS"\)\.replace\("AAVMF_CODE","AAVMF_VARS"\)}{return A.replace("OVMF_CODE","OVMF_VARS").replace("AAVMF_CODE","AAVMF_VARS").replace("edk2-aarch64-code.fd","edk2-arm-vars.fd")} or die "failed to patch firmware vars path\n";
    ' "$asarRoot/.vite/build/index.js"

    rm "$out/lib/claude-desktop/resources/app.asar"
    asar pack --unpack "*.node" "$asarRoot" "$out/lib/claude-desktop/resources/app.asar"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath runtimeBins}
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
      --set-default ELECTRON_OZONE_PLATFORM_HINT auto
    )
  '';

  postFixup = ''
    makeWrapper "$out/lib/claude-desktop/claude-desktop" "$out/bin/claude-desktop" \
      "''${gappsWrapperArgs[@]}"
  '';

  passthru = {
    updateScript = ../../scripts/update.sh;
    inherit sources;
  };

  meta = {
    description = "Official Claude Desktop Linux beta";
    homepage = "https://claude.ai";
    changelog = "https://code.claude.com/docs/en/desktop-linux";
    license = lib.licenses.unfree;
    mainProgram = "claude-desktop";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
  };
})
