# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{10..11} )
inherit autotools multilib-minimal flag-o-matic python-single-r1

DESCRIPTION="Advanced Linux Sound Architecture Library"
HOMEPAGE="https://alsa-project.org/wiki/Main_Page"
if [[ ${PV} == *_p* ]] ; then
	# Please set correct commit ID for a snapshot release!
	COMMIT="abe805ed6c7f38e48002e575535afd1f673b9bcd"
	SRC_URI="https://git.alsa-project.org/?p=${PN}.git;a=snapshot;h=${COMMIT};sf=tgz -> ${P}.tar.gz"
	S="${WORKDIR}"/${PN}-${COMMIT:0:7}
else
	# TODO: Upstream does publish .sig files, so someone could implement verify-sig ;)
	SRC_URI="https://www.alsa-project.org/files/pub/lib/${P}.tar.bz2"
fi

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~sparc ~x86 ~amd64-linux ~x86-linux"
IUSE="alisp debug doc python"
REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

RDEPEND="
	media-libs/alsa-topology-conf
	media-libs/alsa-ucm-conf
	python? ( ${PYTHON_DEPS} )
"
DEPEND="${RDEPEND}"
BDEPEND="doc? ( >=app-doc/doxygen-1.2.6 )"

PATCHES=(
	"${FILESDIR}/${PN}-1.1.6-missing_files.patch" # bug #652422
	"${FILESDIR}/${P}-musl-string.patch" # bug #913573, backport
	"${FILESDIR}/${P}-ump-header-detection.patch" # bug #913573, backport
	"${FILESDIR}/${P}-pcm-fix-segfault-32bit-libs.patch" # backport
	"${FILESDIR}/${P}-reshuffle-included-files-config-h.patch" # backport
	"${FILESDIR}/${P}-lld-17.patch" # bug #914511, backport
)

pkg_setup() {
	use python && python-single-r1_pkg_setup
}

src_prepare() {
	default

	find . -name Makefile.am -exec sed -i -e '/CFLAGS/s:-g -O2::' {} + || die
	# bug #545950
	sed -i -e '5s:^$:\nAM_CPPFLAGS = -I$(top_srcdir)/include:' test/lsb/Makefile.am || die

	eautoreconf
}

multilib_src_configure() {
	# Broken upstream. Could in theory work with -flto-partitions=none
	# but it's a hack to workaround the real problem and not strictly safe.
	# bug #616108, bug #669086, and https://github.com/alsa-project/alsa-lib/issues/6.
	# (This bug is closed as of 1.2.9 but there's been no clear actual fix to it.
	# Let us know if you can identify one.)
	filter-lto

	local myeconfargs=(
		--disable-maintainer-mode
		--disable-resmgr
		--enable-aload
		--enable-rawmidi
		--enable-seq
		--enable-shared
		--enable-thread-safety

		$(multilib_native_use_enable python)
		$(use_enable alisp)
		$(use_with debug)
	)

	ECONF_SOURCE="${S}" econf "${myeconfargs[@]}"
}

multilib_src_compile() {
	emake

	if multilib_is_native_abi && use doc; then
		emake doc
		grep -FZrl "${S}" doc/doxygen/html | \
			xargs -0 sed -i -e "s:${S}::" || die
	fi
}

multilib_src_install() {
	multilib_is_native_abi && use doc && local HTML_DOCS=( doc/doxygen/html/. )

	default
}

multilib_src_install_all() {
	find "${ED}" -type f -name '*.la' -delete || die

	dodoc ChangeLog doc/asoundrc.txt NOTES TODO
}
