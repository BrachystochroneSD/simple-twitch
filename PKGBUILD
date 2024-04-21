# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.1.0
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=('i686' 'x86_64')
url=""
license=('GPL')
depends=('mpv')
# optdepends=()
source=(twitch.sh)
sha256sums=('2838f575bf87184f1dd7e538e89ada4714622c7dd802af5ae6627e4d2fe7eb57')

package() {
  install -Dm755 twitch.sh "$pkgdir/usr/bin/twitch"
}
