/* Precise/Streamer.xs
 * Code from Array::RefElem
 * Copyright (c) 1997-2000 Graham Barr <gbarr@pobox.com>. All rights reserved.
 * This program is free software; you can redistribute it and/or
 * modify it under the same terms as Perl itself.
 *
 * Code From Scalar::Util
 * Copyright 2000 Gisle Aas.
 * This library is free software; you can redistribute it and/or
 * modify it under the same terms as Perl itself.
 *
 * alias_ref is from Lexical::Alias by Jeff Pinyan which
 * was borrowed/modified from Devel::LexAlias by Richard Clamp
 *
 * Additional Code and Modifications
 * Copyright 2003 Yves Orton.
 * This library is free software; you can redistribute it and/or
 * modify it under the same terms as Perl itself.
 */

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#ifndef PERL_VERSION
#    include <patchlevel.h>
#    if !(defined(PERL_VERSION) || (SUBVERSION > 0 && defined(PATCHLEVEL)))
#        include <could_not_find_Perl_patchlevel.h>
#    endif
#    define PERL_REVISION	5
#    define PERL_VERSION	PATCHLEVEL
#    define PERL_SUBVERSION	SUBVERSION
#endif
#if PERL_VERSION < 8
#   define PERL_MAGIC_qr		  'r' /* precompiled qr// regex */
#   define BFD_Svs_SMG_OR_RMG SVs_RMG
#elif PERL_SUBVERSION>=1
#   define BFD_Svs_SMG_OR_RMG SVs_SMG
#else
#   define BFD_Svs_SMG_OR_RMG SVs_RMG
#endif

/*
   the following three subs are outright stolen from Data::Dumper ( Dumper.xs )
   from the 5.6.1 distribution of Perl. Probably Gurusamy Sarathy's work.
   As is much of the code in _globname and globname
*/

/* does a string need to be protected? */
static I32
needs_q(register char *s)
{
TOP:
    if (s[0] == ':') {
        if (*++s) {
            if (*s++ != ':')
                return 1;
        }
        else
            return 1;
    }
    if (isIDFIRST(*s)) {
        while (*++s)
            if (!isALNUM(*s)) {
                if (*s == ':')
                    goto TOP;
                else
                    return 1;
            }
    }
    else
        return 1;
    return 0;
}

/* count the number of "'"s and "\"s in string */
static I32
num_q(register char *s, register STRLEN slen)
{
    register I32 ret = 0;

    while (slen > 0) {
        if (*s == '\'' || *s == '\\')
            ++ret;
        ++s;
        --slen;
    }
    return ret;
}


/* returns number of chars added to escape "'"s and "\"s in s */
/* slen number of characters in s will be escaped */
/* destination must be long enough for additional chars */
static I32
esc_q(register char *d, register char *s, register STRLEN slen)
{
    register I32 ret = 0;

    while (slen > 0) {
        switch (*s) {
        case '\'':
        case '\\':
            *d = '\\';
            ++d; ++ret;
        default:
            *d = *s;
            ++d; ++s; --slen;
            break;
        }
    }
    return ret;
}

MODULE = Data::Dump::Streamer		PACKAGE = Data::Dump::Streamer


int
alias_av(avref, key, val)
	SV* avref
	I32 key
	SV* val
    PROTOTYPE: \@$$
    PREINIT:
	AV* av;
    CODE:
    {
	if (!SvROK(avref) || SvTYPE(SvRV(avref)) != SVt_PVAV)
	   croak("First argument to alias_av() must be an array reference");
	av = (AV*)SvRV(avref);
        SvREFCNT_inc(val);
	if (!av_store(av, key, val)) {
	    SvREFCNT_dec(val);
	    RETVAL=0;
	} else {
	    RETVAL=1;
	}
    }
    OUTPUT:
        RETVAL

void
push_alias(avref, val)
	SV* avref
	SV* val
    PROTOTYPE: \@$
    PREINIT:
	AV* av;
    CODE:
	if (!SvROK(avref) || SvTYPE(SvRV(avref)) != SVt_PVAV)
	   croak("First argument to push_alias() must be an array reference");
	av = (AV*)SvRV(avref);
	SvREFCNT_inc(val);
	av_push(av, val);

int
alias_hv(hvref, key, val)
	SV* hvref
	SV* key
	SV* val
    PROTOTYPE: \%$$
    PREINIT:
	HV* hv;
    CODE:
    {
	if (!SvROK(hvref) || SvTYPE(SvRV(hvref)) != SVt_PVHV)
	   croak("First argument to alias_hv() must be a hash reference");
	hv = (HV*)SvRV(hvref);
        SvREFCNT_inc(val);
	if (!hv_store_ent(hv, key, val, 0)) {
	    SvREFCNT_dec(val);
	    RETVAL=0;
	} else {
	    RETVAL=1;
	}

    }
    OUTPUT:
        RETVAL

char *
blessed(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!sv_isobject(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = sv_reftype(SvRV(sv),TRUE);
}
OUTPUT:
    RETVAL


UV
refaddr(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if(!SvROK(sv)) {
	RETVAL = 0;
    } else {
        RETVAL = PTR2UV(SvRV(sv));
    }
}
OUTPUT:
    RETVAL

IV
refcount(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if(!SvROK(sv)) {
	RETVAL=0;
    } else {
        sv = (SV*)SvRV(sv);
        RETVAL = SvREFCNT(sv);
    }
}
OUTPUT:
    RETVAL

IV
sv_refcount(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    RETVAL = SvREFCNT(sv);
}
OUTPUT:
    RETVAL


bool
is_numeric(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    RETVAL = (SvNIOK(sv)) ? 1 : 0;
}
OUTPUT:
    RETVAL


int
make_ro(sv)
	SV *sv
PROTOTYPE: $
CODE:
  RETVAL = SvREADONLY_on(sv);
OUTPUT:
  RETVAL


int
readonly_set(sv,set)
	SV *sv
	SV *set
PROTOTYPE: $
CODE:
  if (SvTRUE(set)) {
    RETVAL = SvREADONLY_on(sv);
  } else {
    RETVAL = SvREADONLY_off(sv);
  }
OUTPUT:
  RETVAL

int
readonly(sv)
	SV *sv
PROTOTYPE: $
CODE:
  RETVAL = SvREADONLY(sv);
OUTPUT:
  RETVAL

int
looks_like_number(sv)
	SV *sv
PROTOTYPE: $
CODE:
  RETVAL = looks_like_number(sv);
OUTPUT:
  RETVAL




int
alias_ref (dst,src)
	SV *dst
	SV *src
  CODE:
  {
    AV* padv = PL_comppad;
    int dt, st;
    int ok=0;
    I32 i;

    if (!SvROK(src) || !SvROK(dst))
      croak("destination and source must be references");

    dt = SvTYPE(SvRV(dst));
    st = SvTYPE(SvRV(src));

    if (!(dt < SVt_PVAV && st < SVt_PVAV || dt == st && dt <= SVt_PVHV))
      croak("destination and source must be same type (%d != %d)",dt,st);

    for (i = 0; i <= av_len(padv); ++i) {
      SV** myvar_ptr = av_fetch(padv, i, 0);
      if (myvar_ptr) {
        if (SvRV(dst) == *myvar_ptr) {
          av_store(padv, i, SvRV(src));
          SvREFCNT_inc(SvRV(src));
          ok=1;
        }
      }
    }
    if (!ok)
        croak("Failed to created alias");
    RETVAL = ok;
  }
  OUTPUT:
    RETVAL

char *
reftype(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!SvROK(sv)) {
	XSRETURN_NO;
    } else {
        RETVAL = sv_reftype(SvRV(sv),FALSE);
    }
}
OUTPUT:
    RETVAL

char *
_globname(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(SvROK(sv)) {
	XSRETURN_NO;
    } else {
        U32 realtype;
        realtype = SvTYPE(sv);
        if (realtype == SVt_PVGV) {
            STRLEN i;
            RETVAL = SvPV(sv, i);
        } else {
            XSRETURN_NO;
        }
    }
}
OUTPUT:
    RETVAL

SV *
reftype_or_glob(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(SvROK(sv)) {
        RETVAL = newSVpv(sv_reftype(SvRV(sv),FALSE),0);
    } else {
        U32 realtype;
        realtype = SvTYPE(sv);
        if (realtype == SVt_PVGV) {
            char *c, *r;
            STRLEN i;
            /* SV *retval; */

            RETVAL = newSVpvn("", 0);


            /* RETVAL = SvPV(sv, i); */

            c = SvPV(sv, i);


            ++c; --i;                   /* just get the name */
            if (i >= 6 && strncmp(c, "main::", 6) == 0) {
                c += 4;
                i -= 4;
            }
            if (needs_q(c)) {
                sv_grow(RETVAL, 6+2*i);
                r = SvPVX(RETVAL);
                r[0] = '*'; r[1] = '{'; r[2] = '\'';
                i += esc_q(r+3, c, i);
                i += 3;
                r[i++] = '\''; r[i++] = '}';
                r[i] = '\0';
            }
            else {
                sv_grow(RETVAL, i+2);
                r = SvPVX(RETVAL);
                r[0] = '*'; strcpy(r+1, c);
                i++;
            }
            SvCUR_set(RETVAL, i);
            /*sv_2mortal(RETVAL);*/ /*causes an error*/
        } else {
            XSRETURN_NO;
        }
    }
}
OUTPUT:
    RETVAL


SV *
refaddr_or_glob(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(SvROK(sv)) {
        UV uv;
        uv = PTR2UV(SvRV(sv));
        RETVAL = newSVuv(uv);
    } else {
        U32 realtype;
        realtype = SvTYPE(sv);
        if (realtype == SVt_PVGV) {
            char *c, *r;
            STRLEN i;
            /* SV *retval; */

            RETVAL = newSVpvn("", 0);


            /* RETVAL = SvPV(sv, i); */

            c = SvPV(sv, i);


            ++c; --i;                   /* just get the name */
            if (i >= 6 && strncmp(c, "main::", 6) == 0) {
                c += 4;
                i -= 4;
            }
            if (needs_q(c)) {
                sv_grow(RETVAL, 6+2*i);
                r = SvPVX(RETVAL);
                r[0] = '*'; r[1] = '{'; r[2] = '\'';
                i += esc_q(r+3, c, i);
                i += 3;
                r[i++] = '\''; r[i++] = '}';
                r[i] = '\0';
            }
            else {
                sv_grow(RETVAL, i+2);
                r = SvPVX(RETVAL);
                r[0] = '*'; strcpy(r+1, c);
                i++;
            }
            SvCUR_set(RETVAL, i);
            /*sv_2mortal(RETVAL);*/ /*causes an error*/
        } else {
            XSRETURN_NO;
        }
    }
}
OUTPUT:
    RETVAL


SV *
globname(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(SvROK(sv)) {
	XSRETURN_NO;
    } else {
        U32 realtype;
        realtype = SvTYPE(sv);
        if (realtype == SVt_PVGV) {
            char *c, *r;
            STRLEN i;
            /* SV *retval; */

            RETVAL = newSVpvn("", 0);


            /* RETVAL = SvPV(sv, i); */

            c = SvPV(sv, i);


            ++c; --i;                   /* just get the name */
            if (i >= 6 && strncmp(c, "main::", 6) == 0) {
                c += 4;
                i -= 4;
            }
            if (needs_q(c)) {
                sv_grow(RETVAL, 6+2*i);
                r = SvPVX(RETVAL);
                r[0] = '*'; r[1] = '{'; r[2] = '\'';
                i += esc_q(r+3, c, i);
                i += 3;
                r[i++] = '\''; r[i++] = '}';
                r[i] = '\0';
            }
            else {
                sv_grow(RETVAL, i+2);
                r = SvPVX(RETVAL);
                r[0] = '*'; strcpy(r+1, c);
                i++;
            }
            SvCUR_set(RETVAL, i);
            /*sv_2mortal(RETVAL);*/ /*causes an error*/
        } else {
            XSRETURN_NO;
        }
    }
}
OUTPUT:
    RETVAL




SV *
regex(sv)
    SV * sv
PROTOTYPE: $
PREINIT:
    STRLEN patlen;
    char reflags[6];
    int left;
PPCODE:
{
    /*
       Checks if a reference is a regex or not. If the parameter is
       not a ref, or is not the result of a qr// then returns undef.
       Otherwise in list context it returns the pattern and the
       modifiers, in scalar context it returns the pattern just as it
       would if the qr// was blessed into the package Regexp and
       stringified normally.
    */

    if (SvMAGICAL(sv)) { /* is this if needed??? Why?*/
        mg_get(sv);
    }
    if(!SvROK(sv)) {     /* bail if we dont have a ref. */
        XSRETURN_UNDEF;
    }
    patlen=0;
    left=0;
    if (SvTHINKFIRST(sv))
    {
        sv = (SV*)SvRV(sv);
        if (sv)
        {
            MAGIC *mg;
            if (SvTYPE(sv)==SVt_PVMG)
            {
                if ( ((SvFLAGS(sv) &
                       (SVs_OBJECT|SVf_OK|SVs_GMG|SVs_SMG|SVs_RMG))
                      == (SVs_OBJECT|BFD_Svs_SMG_OR_RMG))
                     && (mg = mg_find(sv, PERL_MAGIC_qr)))
                {
                    /* Housten, we have a regex! */
                    regexp *re = (regexp *)mg->mg_obj;
                    I32 gimme = GIMME_V;

                    if ( gimme == G_ARRAY ) {
                        /*
                           we are in list/array context so stringify
                           the modifiers that apply. We ignore "negative
                           modifiers" in this scenario. Also we dont cache
                           the modifiers. AFAICT there isnt anywhere for
                           them to go.  :-(
                        */

                        char *fptr = "msix";
                        char ch;
                        U16 reganch = (U16)((re->reganch & PMf_COMPILETIME) >> 12);

                        while((ch = *fptr++)) {
                            if(reganch & 1) {
                                reflags[left++] = ch;
                            }
                            reganch >>= 1;
                        }
                        /* return the pattern and the modifiers */
                        XPUSHs(sv_2mortal(newSVpvn(re->precomp,re->prelen)));
                        XPUSHs(sv_2mortal(newSVpvn(reflags,left)));
                        XSRETURN(2);
                    } else {
                            /*
                               Non array/list context. So we build up the
                               stringified form just as PL_sv_2pv does,
                               and like it we also cache the result. The
                               entire content of the if() is directly taken
                               from PL_sv_2pv
                            */

                            if (!mg->mg_ptr )
                            {
                                char *fptr = "msix";
                                char ch;
                                int right = 4;
                                char need_newline = 0;
                                U16 reganch = (U16)((re->reganch & PMf_COMPILETIME) >> 12);

                                while((ch = *fptr++)) {
                                    if(reganch & 1) {
                                        reflags[left++] = ch;
                                    }
                                    else {
                                        reflags[right--] = ch;
                                    }
                                    reganch >>= 1;
                                }
                                if(left != 4) {
                                    reflags[left] = '-';
                                    left = 5;
                                }
                                mg->mg_len = re->prelen + 4 + left;
                                /*
                                 * If /x was used, we have to worry about a regex
                                 * ending with a comment later being embedded
                                 * within another regex. If so, we don't want this
                                 * regex's "commentization" to leak out to the
                                 * right part of the enclosing regex, we must cap
                                 * it with a newline.
                                 *
                                 * So, if /x was used, we scan backwards from the
                                 * end of the regex. If we find a '#' before we
                                 * find a newline, we need to add a newline
                                 * ourself. If we find a '\n' first (or if we
                                 * don't find '#' or '\n'), we don't need to add
                                 * anything.  -jfriedl
                                 */
                                if (PMf_EXTENDED & re->reganch)
                                {
                                    char *endptr = re->precomp + re->prelen;
                                    while (endptr >= re->precomp)
                                    {
                                        char c = *(endptr--);
                                        if (c == '\n')
                                            break; /* don't need another */
                                        if (c == '#') {
                                            /* we end while in a comment, so we
                                               need a newline */
                                            mg->mg_len++; /* save space for it */
                                            need_newline = 1; /* note to add it */
    					break;
                                        }
                                    }
                                }
                                /**/
                                New(616, mg->mg_ptr, mg->mg_len + 1 + left, char);
                                Copy("(?", mg->mg_ptr, 2, char);
                                Copy(reflags, mg->mg_ptr+2, left, char);
                                Copy(":", mg->mg_ptr+left+2, 1, char);
                                Copy(re->precomp, mg->mg_ptr+3+left, re->prelen, char);
                                if (need_newline)
                                    mg->mg_ptr[mg->mg_len - 2] = '\n';
                                mg->mg_ptr[mg->mg_len - 1] = ')';
                                mg->mg_ptr[mg->mg_len] = 0;

                            }
                            /* return the pattern in (?msix:..) format */
                            XPUSHs(sv_2mortal(newSVpvn(mg->mg_ptr, mg->mg_len)));
                            XSRETURN(1);
                    }
                }
            }
        }
    }
    /* 'twould appear it aint a regex, so return undef/empty list */
    XSRETURN_UNDEF;
}