# Created by: Erwin Lansing <erwin@FreeBSD.org>
# $FreeBSD$

PORTNAME=	Locale-libintl
PORTVERSION=	1.27
CATEGORIES=	devel perl5
MASTER_SITES=	CPAN
PKGNAMEPREFIX=	p5-
DISTNAME=	libintl-perl-${PORTVERSION}

MAINTAINER=	perl@FreeBSD.org
COMMENT=	Internationalization library for Perl

LICENSE=	LGPL21

USES=		gettext iconv:translit perl5
USE_PERL5=	configure

post-configure:
	@${REINPLACE_CMD} -e '/cd gettext_xs/s=cd =cd $$(.CURDIR)/=' \
		${WRKSRC}/Makefile

post-install:
	${STRIP_CMD} ${STAGEDIR}${PREFIX}/${SITE_ARCH_REL}/auto/Locale/gettext_xs/gettext_xs.so

.include <bsd.port.mk>
