{
  description = "Nix flake for Tobii 4C linux drivers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-20.09";
  };

  outputs = { self, nixpkgs }: {
    #packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
    #defaultPackage.x86_64-linux = self.packages.x86_64-linux.hello;

    packages.x86_64-linux = with import nixpkgs { system = "x86_64-linux"; };
    rec {
      tobii-usbservice = stdenv.mkDerivation {
        name = "tobii-usbservice";
        version = "0.1.6.193_rc";
        src = self;
        buildPhase = ''
          ${pkgs.dpkg}/bin/dpkg-deb -x \
            ./tobiiusbservice_l64U14_2.1.5-28fd4a.deb tobiiusbservice
        '';
        installPhase = ''
          mkdir -p $out/{bin,lib}
          cp tobiiusbservice/usr/local/lib/tobiiusb/libtobii_{libc,osal,usb}.so \
             $out/lib/
          cp tobiiusbservice/usr/local/sbin/tobiiusbserviced $out/bin/
        '';
        fixupPhase = let
          libPath = lib.makeLibraryPath [
            stdenv.cc.libc stdenv.cc.cc.lib pkgs.udev
          ];
        in ''
          patchelf \
            --set-rpath "$out/lib:${libPath}" \
              $out/lib/libtobii_{libc,osal,usb}.so \
              $out/bin/tobiiusbserviced
          patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              $out/bin/tobiiusbserviced
        '';
        # TODO: /var/run/tobiiusb (through systemd service)
      };

    tobii-engine = stdenv.mkDerivation {
        name = "tobii-engine";
        version = "0.1.6.193_rc";
        src = self;
        buildPhase = ''
          ${pkgs.dpkg}/bin/dpkg-deb -x \
            ./tobii_engine_linux-0.1.6.193_rc-Linux.deb tobii-engine
        '';
        installPhase = ''
          mkdir -p $out/{bin,lib}
          mkdir -p $out/usr_dumpster_template/share/tobii_engine/{bin,lib}
          cp -r \
            tobii-engine/usr/share/tobii_engine/db \
            tobii-engine/usr/share/tobii_engine/firmware \
            tobii-engine/usr/share/tobii_engine/model \
            tobii-engine/usr/share/tobii_engine/platform_modules \
            tobii-engine/usr/share/tobii_engine/ssl \
              $out/usr_dumpster_template/share/tobii_engine
          cp tobii-engine/usr/share/tobii_engine/lib/libseeta_facedet_lib.so $out/lib
          cp tobii-engine/usr/share/tobii_engine/lib/libulsTracker.so $out/lib
          cp tobii-engine/usr/share/tobii_engine/lib/libws_srv.so $out/lib
          cp tobii-engine/usr/share/tobii_engine/tobii_engine $out/bin/tobii_engine-unwrapped
          ln -s $out/bin $out/usr_dumpster_template/share/tobii_engine/bin
          ln -s $out/lib $out/usr_dumpster_template/share/tobii_engine/lib
        '';
        fixupPhase = let
          libPath = lib.makeLibraryPath [
            stdenv.cc.libc stdenv.cc.cc.lib pkgs.zlib pkgs.sqlcipher
          ];
        in ''
          find $out/usr_dumpster_template/ |grep libplatmod_is4.so
          patchelf \
            --set-rpath "$out/lib:${libPath}" \
              $out/lib/libseeta_facedet_lib.so \
              $out/lib/libulsTracker.so \
              $out/lib/libws_srv.so \
              $out/usr_dumpster_template/share/tobii_engine/platform_modules/libplatmod_is4.so \
              $out/usr_dumpster_template/share/tobii_engine/platform_modules/libplatmod_pdk.so \
              $out/bin/tobii_engine-unwrapped
          patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              $out/bin/tobii_engine-unwrapped
          statedir=/var/lib/tobii_engine
          cat > $out/bin/tobii_engine << EOF
          #!/bin/sh
          set -uex
          unshare -m $out/bin/tobii_engine-unshared
          EOF
          cat > $out/bin/tobii_engine-unshared << EOF
          #!/bin/sh
          set -uex
          [ -e $statedir ] || \
            ${pkgs.rsync}/bin/rsync -av $out/usr_dumpster_template/* $statedir/
          mount --bind $statedir /usr
          mount --bind $out/lib /usr/share/tobii_engine/lib
          touch /usr/share/tobii_engine/tobii_engine-unwrapped
          mount --bind $out/bin/tobii_engine-unwrapped /usr/share/tobii_engine/tobii_engine-unwrapped
          exec /usr/share/tobii_engine/tobii_engine-unwrapped
          EOF
          chmod +x $out/bin/tobii_engine{,-unshared}
        '';
      };

      # TODO: crashes with sigtrap
      tobii-config = stdenv.mkDerivation {
        name = "tobii-config";
        version = "0.1.6.111";
        src = self;
        buildPhase = ''
          ${pkgs.dpkg}/bin/dpkg-deb -x \
            ./tobii_config_0.1.6.111_amd64.deb tobii-config
        '';
        installPhase = ''
          mkdir -p $out
          cp -r tobii-config/opt $out/
          mkdir -p $out/{bin,lib}
          ln -s $out/opt/tobii_config/tobii_config $out/bin/tobii_config
          mv $out/opt/tobii_config/libnode.so $out/lib/
          mv $out/opt/tobii_config/libffmpeg.so $out/lib/
        '';
        fixupPhase = let
          libPath = lib.makeLibraryPath [
            stdenv.cc.libc stdenv.cc.cc.lib
            alsaLib
            atk
            cairo
            cups
            dbus
            expat
            fontconfig
            freetype
            gdk_pixbuf
            glib
            gnome2.GConf
            gtk2
            libpulseaudio
            nspr
            nss
            pango
            xorg.libX11
            xorg.libXScrnSaver
            xorg.libXcomposite
            xorg.libXcursor
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXi
            xorg.libXrandr
            xorg.libXrender
            xorg.libXtst
            xorg.libxcb

            udev
            #glibc
            #libopus
            #libogg
            #libvorbis
            #flac
            #libsndfile
            #pciutils
          ];
        in ''
          patchelf \
            --set-rpath "$out/lib:${libPath}" \
              $out/lib/libnode.so \
              $out/lib/libffmpeg.so \
              $out/opt/tobii_config/resources/resources/libtobii_stream_engine.so \
              $out/opt/tobii_config/tobii_config
          patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              $out/opt/tobii_config/tobii_config
        '';
      };

      tobii-manager = stdenv.mkDerivation {
        name = "tobii-manager";
        version = "1.12.1";
        src = self;
        buildPhase = ''
          ${pkgs.dpkg}/bin/dpkg-deb -x \
            ./TobiiProEyeTrackerManager-2.1.0.deb tobii-manager
        '';
        installPhase = ''
          mkdir -p $out
          cp -r tobii-manager/opt $out/
          mkdir -p $out/{bin,lib}
          ln -s $out/opt/TobiiProEyeTrackerManager/tobiiproeyetrackermanager $out/bin/tobii_manager
          mv $out/opt/TobiiProEyeTrackerManager/libEGL.so $out/lib/
          mv $out/opt/TobiiProEyeTrackerManager/libGLESv2.so $out/lib/
          mv $out/opt/TobiiProEyeTrackerManager/libVkICD_mock_icd.so $out/lib/
          mv $out/opt/TobiiProEyeTrackerManager/libffmpeg.so $out/lib/
          mv $out/opt/TobiiProEyeTrackerManager/resources/stage/sdk/libraries/lib/libtobii_firmware_upgrade.so $out/lib/
          mv $out/opt/TobiiProEyeTrackerManager/resources/stage/sdk/libraries/lib/libtobii_research.so $out/lib/
          rm -r $out/opt/TobiiProEyeTrackerManager/resources/stage/sdk/libraries
          rm -r $out/opt/TobiiProEyeTrackerManager/swiftshader
        '';
        fixupPhase = let
          libPath = lib.makeLibraryPath [
            stdenv.cc.libc stdenv.cc.cc.lib
            alsaLib
            at-spi2-atk
            atk
            cairo
            cups
            dbus
            expat
            gdk_pixbuf
            glib
            gtk3
            libuuid
            nspr
            nss
            pango
            xorg.libX11
            xorg.libXScrnSaver
            xorg.libXcomposite
            xorg.libXcursor
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXi
            xorg.libXrandr
            xorg.libXrender
            xorg.libXtst
            xorg.libxcb

            gcc
            udev
            #fontconfig
            #freetype
            #gnome2.GConf
            #gtk2
            #libpulseaudio
            #harfbuzz
            #glibc
            #libopus
            #libogg
            #libvorbis
            #flac
            #libsndfile
            #pciutils
          ];
        in ''
          patchelf \
            --set-rpath "$out/lib:${libPath}" \
              $out/lib/libffmpeg.so \
              $out/lib/libEGL.so \
              $out/lib/libGLESv2.so \
              $out/lib/libVkICD_mock_icd.so \
              $out/opt/TobiiProEyeTrackerManager/tobiiproeyetrackermanager
          patchelf \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              $out/opt/TobiiProEyeTrackerManager/tobiiproeyetrackermanager
        '';
      };

      tobii-library = stdenv.mkDerivation {
        name = "tobii-library";
        version = "1";
        src = self;
        buildPhase = ":";
        installPhase = ''
          mkdir -p $out/{lib,include}
          cp -r lib/include/* $out/include/
          cp lib/lib/x64/libtobii_stream_engine.so $out/lib/
        '';
        fixupPhase = let
          libPath = lib.makeLibraryPath [ stdenv.cc.libc stdenv.cc.cc.lib ];
        in ''
          patchelf \
            --set-rpath "$out/lib:${libPath}" \
              $out/lib/libtobii_stream_engine.so
        '';
      };

      tobii-example = stdenv.mkDerivation {
        name = "tobii-example";
        version = "1";
        src = self;
        nativeBuildInputs = [ tobii-library ];
        buildPhase = ''
          pushd example
          make LDFLAGS="-lpthread -ltobii_stream_engine" main
          popd
        '';
        installPhase = ''
          mkdir -p $out/bin
          cp example/main $out/bin/tobii_example
        '';
      };

      tobii-metapackage = stdenv.mkDerivation {
        name = "tobii-usbservice";
        version = "0.1.6.193_rc";
        src = self;
        buildPhase = ":";
        installPhase = ''
          mkdir -p $out/bin/
          ln -s ${tobii-usbservice}/bin/tobiiusbserviced $out/bin/tobii_usbserviced
          ln -s ${tobii-engine}/bin/tobii_engine $out/bin/
          ln -s ${tobii-config}/bin/tobii_config $out/bin/
          ln -s ${tobii-manager}/bin/tobii_manager $out/bin/
          ln -s ${tobii-example}/bin/tobii_example $out/bin/
        '';
      };
    };

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.tobii-metapackage;
  };
}
