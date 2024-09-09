# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.2.0
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=(any)
url=""
license=('GPL')
depends=(mpv curl)
optdepends=()
backup=(etc/twitch.conf)
source=(
  twitch.sh
  twitch.conf
)
sha256sums=('777ac0392bf6ad5cdd77f1ec60cb22279bc86b341780cb45cee0da33d4a28ee5'
            '6a30f61201159d53b23c2483135ed088e841f47fbbd95676bd23625d83dff529')

package() {
  install -Dm600 twitch.conf "$pkgdir/etc/twitch.conf"
  install -Dm755 twitch.sh "$pkgdir/usr/bin/twitch"
}
