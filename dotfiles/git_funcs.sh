rebase_interactive () {
    if [ -z "$1" ]
    then
        BRANCH="master"
    else
        BRANCH="${1}"
    fi

    git rebase -i HEAD~"$(git rev-list --count HEAD ^origin/"${BRANCH}")"
}

sync () {
    if [ -z "$1" ]
    then
        BRANCH="master"
    else
        BRANCH="${1}"
    fi

    git fetch && \
        git rebase origin/"${BRANCH}" --stat
}

stat () {
    git diff HEAD~"${1}" --stat
}

squash () {
    git reset --soft HEAD~"${1}" && \
        git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"
}

update () {
    if [ -z "$1" ]
    then
        BRANCH="master"
    else
        BRANCH="${1}"
    fi

    git fetch && \
        git reset --hard origin/"${BRANCH}"
}

remove_all_files () {
    git clean -fdx
}

remove_old_branches () {
    git fetch --prune; \
        git branch --merged master | grep -v '^[ *]*master$' | xargs git branch -d
}
