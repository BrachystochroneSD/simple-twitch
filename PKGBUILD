# Maintainer:  <samueld@mailo.com>
pkgname=simple-twitch
pkgver=0.3.0
pkgrel=1
pkgdesc="Simple script to access twitch simply"
arch=(any)
url="https://www.github.com/BrachystochroneSD/simple-twitch"
license=('GPL')
depends=(jq sed gawk mpv curl)
optdepends=()
backup=(etc/twitch.conf)
source=(
  twitch.desktop
  twitch_lib.sh
  twitch.sh
  twitch.conf
)
sha256sums=('e1e600aef687525be7e4ad6e4abc0ab5099930569853a8ae572caaa208e57104'
            '1741be607aaac4ccae8b030fffad9916183b0ef2a877845c26a168b4070b7086'
            '05bf1819bc3e909bf582e79f66d497ffddb1b8195f2d3a92008d13df283bd7d1'
            '6a30f61201159d53b23c2483135ed088e841f47fbbd95676bd23625d83dff529')

package() {
  install -Dm644 twitch_lib.sh "$pkgdir/usr/share/twitch/twitch_lib.sh"

  install -Dm600 twitch.conf "$pkgdir/etc/twitch.conf"
  install -Dm755 twitch.sh "$pkgdir/usr/bin/twitch"
}
