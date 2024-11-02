# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.2.1
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=(any)
url="https://www.github.com/BrachystochroneSD/simple-twitch"
license=('GPL')
depends=(mpv curl)
optdepends=()
backup=(etc/twitch.conf)
source=(
  twitch.sh
  twitch.conf
)
sha256sums=('593f2aaf0d59f36c22249d414ead95436534286fb4823cb5665d7fecdcd5a5cc'
            '6a30f61201159d53b23c2483135ed088e841f47fbbd95676bd23625d83dff529')

package() {
  install -Dm600 twitch.conf "$pkgdir/etc/twitch.conf"
  install -Dm755 twitch.sh "$pkgdir/usr/bin/twitch"
}
