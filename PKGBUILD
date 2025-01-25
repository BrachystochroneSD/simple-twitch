# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.3.0
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=(any)
url="https://www.github.com/BrachystochroneSD/${pkgname}"
license=('GPL')
depends=(jq sed gawk mpv curl)
optdepends=()
backup=(etc/${pkgname}.conf)
source=(
  ${pkgname}.desktop
  ${pkgname}-lib.sh
  ${pkgname}.sh
  ${pkgname}.conf
)
sha256sums=('549dc0a782e806b7160f02eac53cf29e1ac308e4642a15227454d362d586eb82'
            '641ddfaf1ea13477a7b7855a9efc329b82a4e0122a45f4a38c5893ec188e1cd1'
            '3f1412637bc2deaa493c8f178d419fbf0aa9eb955be4240932f45bd92cc3fdb5'
            '6a30f61201159d53b23c2483135ed088e841f47fbbd95676bd23625d83dff529')

package() {
  install -Dm644 ${pkgname}.desktop "$pkgdir/usr/share/applications/${pkgname}.desktop"
  install -Dm644 ${pkgname}-lib.sh "$pkgdir/usr/share/${pkgname}/${pkgname}-lib.sh"

  install -Dm600 ${pkgname}.conf "$pkgdir/etc/${pkgname}.conf"
  install -Dm755 ${pkgname}.sh "$pkgdir/usr/bin/${pkgname}"
}
