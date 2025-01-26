# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.5.0
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=(any)
url="https://www.github.com/BrachystochroneSD/${pkgname}"
license=('GPL')
depends=(jq sed awk mpv curl grep)
optdepends=()
backup=(etc/${pkgname}.conf)
source=(
  ${pkgname}.service
  ${pkgname}.timer
  twitch-stream-notif.sh
  ${pkgname}.desktop
  ${pkgname}-lib.sh
  ${pkgname}.sh
  ${pkgname}.conf
)
sha256sums=('e50927dd0b4ced490da67d178dd5db7aae3fad9ff0372f4a119836be65487116'
            '93860d9a56647de0ac91a23dbeadcfb30796dcc17b3da2d1595c033e4bf355aa'
            'c3e1e6e061733a1fb4be595ecd64001ad4187b8dcf617cb158d6aea047bd41d2'
            '549dc0a782e806b7160f02eac53cf29e1ac308e4642a15227454d362d586eb82'
            '2eb4e107c6f94c92658ad44c64ccb5fe24625139ca01970408af013a988be509'
            'cda8f08b7b1b1a006ef43f3b0efbc4dd37833b9331aa8693c36840a22f23e518'
            '6a30f61201159d53b23c2483135ed088e841f47fbbd95676bd23625d83dff529')

package() {
  install -Dm644 ${pkgname}.service "$pkgdir/usr/lib/systemd/user/${pkgname}.service"
  install -Dm644 ${pkgname}.timer "$pkgdir/usr/lib/systemd/user/${pkgname}.timer"

  install -Dm644 twitch-stream-notif.sh "$pkgdir/var/lib/simple-twitch/twitch-stream-notif.sh"

  install -Dm644 ${pkgname}.desktop "$pkgdir/usr/share/applications/${pkgname}.desktop"
  install -Dm644 ${pkgname}-lib.sh "$pkgdir/usr/share/${pkgname}/${pkgname}-lib.sh"

  install -Dm600 ${pkgname}.conf "$pkgdir/etc/${pkgname}.conf"
  install -Dm755 ${pkgname}.sh "$pkgdir/usr/bin/${pkgname}"
}
