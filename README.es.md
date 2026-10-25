# TICS

[Read in English](README.md)

Tu Mac suena como un teclado mecánico al teclear, y como un ratón al hacer clic.

Versión 0.1.0

## Qué hace

TICS vive en la barra de menús. Cada tecla que pulsas, en cualquier app, suena con el teclado
que elijas.

- **11 teclados**: Cherry MX Blue, Brown y Red, Holy Panda, Cream, MX Blue, MX Brown, Oreo,
  Topre Purple, Turquoise y uno sintético, calculado con código.
- **Pulsar y soltar** suenan distinto, y mantener una tecla pulsada suena más flojo en cada
  repetición.
- **Clics, arrastres y rueda**: el ratón suena también, a la misma altura que el teclado que
  tienes. Arrastrar suena como un trinquete, más seguido cuanto más deprisa, y la rueda, a cada
  muesca.
- **Ajustes del ratón**: el tono, el volumen y lo seco o hueco que suena cada botón, el arrastre
  y la rueda, y los oyes mientras los ajustas.
- **Ratones Logitech**: si Logi Options+ se queda algún botón (atrás, adelante, gestos…), enciende
  la ficha «Logitech» y suena también. Con el ratón conectado por Bluetooth. Con un MX Master 4,
  además, cada botón puede vibrar al pulsarlo, con el efecto que elijas en los ajustes del ratón.
- **En español y en inglés**: TICS sale en el idioma de tu Mac.

## Privacidad

TICS necesita el permiso **Monitorización de los dispositivos de entrada** para saber qué tecla
pulsas y elegir su sonido. Solo escucha: no guarda nada de lo que escribes ni dónde haces clic, y
no se conecta a internet.

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
