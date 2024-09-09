# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.1.2
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=(any)
url=""
license=('GPL')
depends=('mpv')
optdepends=()
backup=(etc/twitch.conf)
source=(
  twitch.sh
  twitch.conf
)
sha256sums=('29387428fc29a059d29274c714ab7cf04dcbf9be539d2261f28552a9aa287539'
            '6a30f61201159d53b23c2483135ed088e841f47fbbd95676bd23625d83dff529')

package() {
  install -Dm600 twitch.conf "$pkgdir/etc/twitch.conf"
  install -Dm755 twitch.sh "$pkgdir/usr/bin/twitch"
}
