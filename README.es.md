# TICS

[Read in English](README.md)

Tu Mac suena como un teclado mecánico al teclear, y como un ratón al hacer clic.

Versión 0.4.0

[![Mira TICS en YouTube, con sonido](https://img.youtube.com/vi/_GZCnr1pWfg/maxresdefault.jpg)](https://youtu.be/_GZCnr1pWfg)

**[Míralo en YouTube](https://youtu.be/_GZCnr1pWfg)**, con el sonido puesto.

## Descarga

**[Descarga TICS](https://github.com/yestoall/tics/releases/latest/download/TICS.dmg)**, gratis.
Abre el .dmg y arrastra TICS a Aplicaciones. Pide macOS 14 o posterior y va en Mac con Apple
silicon e Intel. La primera vez que la abres, macOS te pide permiso para escuchar el teclado.

O instálala con [Homebrew](https://brew.sh):

```bash
brew install --cask yestoall/tap/tics
```

Para ponerla al día más adelante, usa `brew upgrade --cask tics`.

## Por qué

TICS la hice para mí. Hay algo en el clac de un teclado mecánico que sienta bien: cada tecla te
contesta. Usaba [JoyTap](https://setapp.com/apps/joytap), una app de pago que hace algo parecido,
pero echaba en falta cosas, como que también sonara el ratón. Así que hice la mía.

Si se te ocurre cómo mejorarla, [cuéntamelo en GitHub](https://github.com/yestoall/tics/issues).
Lo mismo me animo a hacerlo yo, o lo mismo prefieres hacerlo tú.

## Qué hace

TICS vive en la barra de menús. Cada tecla que pulsas, en cualquier app, suena con el teclado
que elijas.

- **11 teclados**: Cherry MX Blue, Brown y Red, Holy Panda, Cream, MX Blue, MX Brown, Oreo,
  Topre Purple, Turquoise y uno sintético, calculado con código.
- **Pulsar y soltar** suenan distinto, y mantener una tecla pulsada suena más flojo en cada
  repetición.
- **Cada pulsación, un poco distinta**: el tono cambia un poco de una vez a otra, como en un
  teclado de verdad. Se apaga con **Variar el tono**, en **Configurar teclado…**.
- **Tu teclado, a tu manera**: en **Configurar teclado…**, haz que un grupo de teclas (las
  normales, el espacio, Return o las anchas), una sola tecla o un atajo suenen como los de otro
  pack, con su tono y su volumen. A una tecla o un atajo también le puedes poner un sonido tuyo:
  elige **Fichero…** o arrastra encima un fichero de audio.
- **Clics, arrastres y rueda**: el ratón suena también, a la misma altura que el teclado que
  tienes. Arrastrar suena como un trinquete, más seguido cuanto más deprisa, y la rueda, a cada
  muesca.
- **Ajustes del ratón**: el tono, el volumen y lo seco o hueco que suena cada botón, el arrastre
  y la rueda, y los oyes mientras los ajustas.
- **Ratones Logitech**: si Logi Options+ se queda algún botón (atrás, adelante, gestos…), enciende
  la ficha «Logitech» y suena también. Con el ratón conectado por Bluetooth. Con un MX Master 4,
  además, cada botón puede vibrar al pulsarlo, con el efecto que elijas en los ajustes del ratón.
- **Más bajo con otro audio**: mientras suena música, un vídeo o una llamada, TICS baja al 40 % de
  tu volumen y vuelve unos segundos después de que pare. También puedes bajarlo o callarlo a mano
  desde la fila del volumen, sin cerrarlo.
- **En español y en inglés**: TICS sale en el idioma de tu Mac.

## Privacidad

TICS necesita el permiso **Monitorización de los dispositivos de entrada** para saber qué tecla
pulsas y elegir su sonido. Solo escucha: no guarda nada de lo que escribes ni dónde haces clic.

Para saber si suena otro audio, TICS mira qué apps están usando los altavoces, como lo cuenta
macOS. No oye lo que suena ni pide ningún permiso.

TICS solo se conecta a internet al abrirse y luego una vez al día, para preguntar a GitHub el
número de la última versión, y no manda nada más. Si hay una más nueva, te lo dice el panel y el
icono de la barra lleva un punto rojo. Apaga **Buscar actualizaciones** en el panel y TICS no se
conecta nunca.

Con la ficha «Logitech» encendida, pide también el permiso de **Bluetooth**, para oír los botones
que se queda Logi Options+. Solo escucha cuándo los pulsas y los sueltas: no cambia nada del ratón.

## Compilar

Necesitas macOS 14 o posterior y Swift 6 (Xcode o sus herramientas de línea de comandos).

```bash
bun run dev     # compila en debug y abre la app
bun run build   # compila en release: build/Tics.app
bun run test    # los tests
```

Sin Bun: `scripts/build-app.sh release && open build/Tics.app`.

La app se firma con tu certificado «Apple Development» si lo tienes, o con otro que elijas en
`SIGN_IDENTITY`. Sin certificado se firma ad hoc: funciona igual, pero macOS te vuelve a pedir el
permiso después de cada compilación.

## Sonidos

Los teclados usan el formato de [Mechvibes](https://github.com/hainguyents13/mechvibes) y
salen de dos proyectos con licencia MIT:

- [Mechvibes](https://github.com/hainguyents13/mechvibes): Oreo, Cherry MX Blue, Brown y Red, y
  Topre Purple. Licencia en `Resources/SoundPacks/LICENSE-mechvibes`.
- [kbsim](https://github.com/tplai/kbsim): Holy Panda, Cream, MX Blue, MX Brown y Turquoise. Cada
  carpeta lleva su licencia.

Los clics del ratón y el teclado sintético no salen de ningún fichero: los calcula TICS al vuelo.

## Licencia

[MIT](LICENSE).

diseñado con ♥ por [@yestoall](https://yestoall.com)
