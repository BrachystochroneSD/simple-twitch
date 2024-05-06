# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.1.0
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=('i686' 'x86_64')
url=""
license=('GPL')
depends=('mpv')
optdepends=()
backup=(etc/twitch.conf)
source=(
  twitch.sh
  twitch.conf
)
sha256sums=('bbd7fbb2e9e45c31e1838709290b511eb859095eb5424d7b27a7df99afa825a0'
            'b4498a92f391b7e1da268052bc691fe3c700a7c73479b4d358ba3cc7aed72777')

package() {
  install -Dm600 twitch.conf "$pkgdir/etc/twitch.conf"
  install -Dm755 twitch.sh "$pkgdir/usr/bin/twitch"
}
