enum DirectoryType {
  CACHE,
  APP_DOCUMENTS,
}

enum SourceType {
  LOCAL,
  REMOTE,
}

enum DownloadStatusType {
  initial,
  queued,
  downloading,
  canceled,
  downloaded,
}