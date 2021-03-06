#!/bin/sh

force=
do_compile=t
while test $# -gt 0
do
	case "$1" in
	-f|--force)
		force=t
		shift
		;;
	-n|--no-compile)
		do_compile=
		shift
		;;
	*)
		break
	esac
done

test -z "$1" && {
	echo "Usage: $0 [-f] [-n] <version>" >&2
	exit 1
}

version=$1

test -z "$force" && {
	die () {
		echo "$*" >&2
		echo "If that is okay, please call '$0 -f $version'" >&2
		exit 1
	}

	(cd /git &&
	 git update-index --refresh &&
	 git diff-files --quiet &&
	 git diff-index --cached HEAD --) ||
	die "Git submodule has dirty files"
	(cd / &&
	 git update-index --refresh &&
	 git diff-files --quiet &&
	 git diff-index --cached HEAD --) ||
	die "msysGit super project not up-to-date"
}

create_msysgit_tag () {
	i=0 &&
	tag=$(git describe HEAD | cut -d- -f1) &&
	tag=${tag%.msysgit.*} &&
	while ! git tag -a -m "Git for Windows $1" $tag.msysgit.$i
	do
		i=$(($i+1))
	done
}

# compile everything needed for standard setup
test "$do_compile" && {
	wordpad /share/WinGit/ReleaseNotes.rtf && {
		(cd / &&
		 # create a commit if ReleaseNotes changed
		 if test ! -z "$(git diff /share/WinGit/ReleaseNotes.rtf)"
		 then
			git add /share/WinGit/ReleaseNotes.rtf &&
			git commit -m "Git for Windows $version"
		 fi) &&
		(cd /git &&
		 create_msysgit_tag $version &&
		 make install) &&
		(cd /src/git-cheetah/explorer/ && make)
	} || exit 1
}

test -z "$force" && {
	die () {
		echo "$*" >&2
		echo "If that is okay, please call '$0 -f $version'" >&2
		exit 1
	}

	(cd /git &&
	 git update-index --refresh &&
	 git diff-files --quiet &&
	 git diff-index --cached HEAD --) ||
	die "Git submodule has dirty files"
	(cd /git &&
	 test git.exe = $((printf 'git.exe\0'; git ls-files -z) | xargs --null ls -t 2>/dev/null| head -1)) ||
	die "Git's git.exe is not up-to-date (run 'cd /git && make' to fix)"
	for f in /bin/git* /libexec/git-core/git*
	do
		case "$f" in
		*.manifest)
			continue
			;;
		*/gitk)
			basename=gitk-git/gitk
			;;
		*/git-citool|*/git-gui)
			basename=git-gui/git-gui
			;;
		*/git-gui--askpass|*/git-gui--askyesno|*/git-gui.tcl)
			basename=git-gui/$(basename "$f")
			;;
		*)
			basename=$(basename "$f")
			;;
		esac
		cmp "$f" "/git/$basename" ||
		die "Installed Git disagrees with contents of /git/ ($f)"
	done
	(cd / &&
	 git update-index --refresh &&
	 git diff-files --quiet &&
	 git diff-index --cached HEAD --) ||
	die "msysGit super project not up-to-date"
	(cd /git &&
	 test ! -z "$(git tag --contains HEAD)") ||
	die "Git's HEAD is untagged"
}

TMPDIR=/tmp/WinGit
unset DONT_REMOVE_BUILTINS

/share/WinGit/copy-files.sh $TMPDIR &&
sed -e '/share\/msysGit/d' -e "s/msysGit/Git (version $version)/" \
	< /etc/motd > $TMPDIR/etc/motd &&
cp /share/resources/gpl-2.0.rtf /share/resources/git.bmp /share/resources/gitsmall.bmp $TMPDIR &&
sed -e "s/%APPVERSION%/$version/" \
	< /share/WinGit/install.iss > $TMPDIR/install.iss &&
cp /share/WinGit/*.inc.iss $TMPDIR &&
echo "Launching Inno Setup compiler ..." &&
(/share/InnoSetup/ISCC.exe "$TMPDIR/install.iss" -q > /tmp/install.out;
 echo $? > /tmp/install.status) &&
(grep -Ev "\s*Reading|\s*Compressing" < /tmp/install.out;
 test 0 = "$(cat /tmp/install.status)") &&
(cd / && git tag -a -m "Git for Windows $1" Git-$1) &&
echo "Installer is available as $USERPROFILE/Git-$version.exe"
