#' Stage and commit changes
#'
#' @description
#' To commit changes, start by *staging* the files to be included in the commit
#' using `git_add()` or `git_rm()`. Use `git_status()` to see an overview of
#' staged and unstaged changes, and finally `git_commit()` creates a new commit
#' with currently staged files.
#'
#' `git_commit_all()` is a convenience function that automatically stages and
#' commits all modified files. Note that `git_commit_all()` does **not** add
#' new, untracked files to the repository. You need to make an explicit call to
#' `git_add()` to start tracking new files.
#'
#' `git_log()` shows the most recent commits and `git_ls()` lists all the files
#' that are being tracked in the repository. `git_stat_files()`
#'
#' @export
#' @rdname git_commit
#' @name git_commit
#' @family git
#' @inheritParams git_open
#' @param message a commit message
#' @param author A [git_signature] value, default is [git_signature_default()].
#' @param committer A [git_signature] value, default is same as `author`
#' @return
#' * `git_status()`, `git_ls()`: A data frame with one row per file
#' * `git_log()`: A data frame with one row per commit
#' * `git_commit()`, `git_commit_all()`: A SHA
#' @useDynLib gert R_git_commit_create
#' @examples
#' oldwd <- getwd()
#' repo <- file.path(tempdir(), "myrepo")
#' git_init(repo)
#' setwd(repo)
#'
#' # Set a user if no default
#' if(!user_is_configured()){
#'   git_config_set("user.name", "Jerry")
#'   git_config_set("user.email", "jerry@gmail.com")
#' }
#'
#' writeLines(letters[1:6], "alphabet.txt")
#' git_status()
#'
#' git_add("alphabet.txt")
#' git_status()
#'
#' git_commit("Start alphabet file")
#' git_status()
#'
#' git_ls()
#'
#' git_log()
#'
#' cat(letters[7:9], file = "alphabet.txt", sep = "\n", append = TRUE)
#' git_status()
#'
#' git_commit_all("Add more letters")
#'
#' # cleanup
#' setwd(oldwd)
#' unlink(repo, recursive = TRUE)
git_commit <- function(message, author = NULL, committer = NULL, repo = '.'){
  repo <- git_open(repo)
  if(!length(author)) {
    author <- git_signature_default(repo = repo)
  } else {
    git_signature_parse(author) #validate
  }
  if(!length(committer)){
    committer <- author
  } else {
    git_signature_parse(committer)  #validate
  }
  stopifnot(is.character(message), length(message) == 1)
  status <- git_status(repo = repo)
  if(!any(status$staged))
    stop("No staged files to commit. Run git_add() to select files.")
  merge_parents <- git_merge_parent_heads(repo = repo)
  .Call(R_git_commit_create, repo, message, author, committer, merge_parents)
}

#' @export
#' @rdname git_commit
git_commit_all <- function(message, author = NULL, committer = NULL, repo = '.'){
  repo <- git_open(repo)
  unstaged <- git_status(staged = FALSE, repo = repo)

  changes <- unstaged$file[unstaged$status %in% c("modified", "renamed", "typechange")]
  if(length(changes))
    git_add(changes, repo = repo)

  deleted <- unstaged$file[unstaged$status == "deleted"]
  if(length(deleted))
    git_rm(deleted, repo = repo)

  git_commit(message = message, author = author, committer = committer, repo = repo)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_commit_info
git_commit_info <- function(ref = "HEAD", repo = '.'){
  repo <- git_open(repo)
  .Call(R_git_commit_info, repo, ref)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_commit_id
git_commit_id <- function(ref = "HEAD", repo = '.'){
  repo <- git_open(repo)
  .Call(R_git_commit_id, repo, ref)
}

#' @export
#' @rdname git_commit
#' @param ancestor a reference to a potential ancestor commit
#' @useDynLib gert R_git_commit_descendant
git_commit_descendant_of <- function(ancestor, ref = 'HEAD', repo = '.'){
  repo <- git_open(repo)
  .Call(R_git_commit_descendant, repo, ref, ancestor)
}

#' @export
#' @rdname git_commit
#' @param files vector of paths relative to the git root directory.
#' Use `"."` to stage all changed files.
#' @param force add files even if in gitignore
#' @useDynLib gert R_git_repository_add
git_add <- function(files, force = FALSE, repo = '.'){
  repo <- git_open(repo)
  info <- git_info(repo)
  normalizePath(file.path(info$path, files), mustWork = FALSE)
  force <- as.logical(force)
  .Call(R_git_repository_add, repo, files, force)
  git_status(repo = repo)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_repository_rm
git_rm <- function(files, repo = '.'){
  repo <- git_open(repo)
  info <- git_info(repo)
  normalizePath(file.path(info$path, files), mustWork = FALSE)
  .Call(R_git_repository_rm, repo, files)
  git_status(repo = repo)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_status_list
#' @param staged return only staged (TRUE) or unstaged files (FALSE).
#' Use `NULL` or `NA` to show both (default).
#' @param pathspec character vector with paths to match
git_status <- function(staged = NULL, pathspec = NULL, repo = '.'){
  repo <- git_open(repo)
  staged <- as.logical(staged)
  pathspec <- as.character(pathspec)
  df <- .Call(R_git_status_list, repo, staged, pathspec)
  df[order(df$file), ,drop = FALSE]
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_conflict_list
git_conflicts <- function(repo = '.'){
  repo <- git_open(repo)
  .Call(R_git_conflict_list, repo)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_repository_ls
git_ls <- function(repo = '.', ref = NULL){
  repo <- git_open(repo)
  if(!length(ref) && isTRUE(git_info(repo = repo)$bare)){
    ref <- 'HEAD'
  }
  .Call(R_git_repository_ls, repo, ref = ref)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_commit_log
#' @param ref revision string with a branch/tag/commit value
#' @param max lookup at most latest n parent commits
#' @param after date or timestamp: only include commits starting this date
git_log <- function(ref = "HEAD", max = 100, after = NULL, repo = "."){
  repo <- git_open(repo)
  ref <- as.character(ref)
  max <- as.integer(max)
  if(length(after))
    after <- as.POSIXct(after)
  .Call(R_git_commit_log, repo, ref, max, after)
}

#' @export
#' @rdname git_commit
#' @useDynLib gert R_git_stat_files
git_stat_files <- function(files, ref = "HEAD", repo = '.'){
  repo <- git_open(repo)
  files <- as.character(files)
  .Call(R_git_stat_files, repo, files, ref)
}

assert_string <- function(x){
  if(!is.character(x) || !length(x))
    stop("Argument must be a string of length 1")
}
