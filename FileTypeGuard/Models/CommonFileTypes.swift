import Foundation
import UniformTypeIdentifiers

/// 常见文件类型预设清单
struct CommonFileTypes {

    /// 文件类型分类
    enum Category: String, CaseIterable, Identifiable {
        case documents
        case images
        case videos
        case audio
        case archives
        case code
        case data

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .documents: return String(localized: "category_documents")
            case .images: return String(localized: "category_images")
            case .videos: return String(localized: "category_videos")
            case .audio: return String(localized: "category_audio")
            case .archives: return String(localized: "category_archives")
            case .code: return String(localized: "category_code")
            case .data: return String(localized: "category_data")
            }
        }

        var icon: String {
            switch self {
            case .documents: return "doc.text.fill"
            case .images: return "photo.fill"
            case .videos: return "video.fill"
            case .audio: return "waveform"
            case .archives: return "archivebox.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .data: return "tablecells.fill"
            }
        }
    }

    /// 预设文件类型定义
    struct PresetFileType: Identifiable, Hashable {
        let id = UUID()
        let displayName: String
        let extensions: [String]
        let uti: String
        let category: Category
        let icon: String

        /// 转换为 FileType
        func toFileType() -> FileType {
            FileType(
                uti: uti,
                extensions: extensions,
                displayName: displayName
            )
        }
    }

    // MARK: - 预设列表

    static let allTypes: [PresetFileType] = [
        // 文档类
        PresetFileType(
            displayName: String(localized: "filetype_pdf_document"),
            extensions: [".pdf"],
            uti: "com.adobe.pdf",
            category: .documents,
            icon: "doc.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_word_document"),
            extensions: [".doc", ".docx"],
            uti: "org.openxmlformats.wordprocessingml.document",
            category: .documents,
            icon: "doc.text.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_excel_spreadsheet"),
            extensions: [".xls", ".xlsx"],
            uti: "org.openxmlformats.spreadsheetml.sheet",
            category: .documents,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_powerpoint_presentation"),
            extensions: [".ppt", ".pptx"],
            uti: "org.openxmlformats.presentationml.presentation",
            category: .documents,
            icon: "chart.bar.doc.horizontal.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_text_file"),
            extensions: [".txt"],
            uti: "public.plain-text",
            category: .documents,
            icon: "doc.plaintext.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_rtf_document"),
            extensions: [".rtf"],
            uti: "public.rtf",
            category: .documents,
            icon: "doc.richtext.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_markdown_document"),
            extensions: [".md", ".markdown"],
            uti: "net.daringfireball.markdown",
            category: .documents,
            icon: "text.alignleft"
        ),
        PresetFileType(
            displayName: "ODT Document",
            extensions: [".odt"],
            uti: "org.oasis-open.opendocument.text",
            category: .documents,
            icon: "doc.text.fill"
        ),
        PresetFileType(
            displayName: "EPUB Book",
            extensions: [".epub"],
            uti: "org.idpf.epub-container",
            category: .documents,
            icon: "book.fill"
        ),
        PresetFileType(
            displayName: "Pages Document",
            extensions: [".pages"],
            uti: "com.apple.iwork.pages.pages",
            category: .documents,
            icon: "doc.richtext.fill"
        ),
        PresetFileType(
            displayName: "Numbers Spreadsheet",
            extensions: [".numbers"],
            uti: "com.apple.iwork.numbers.numbers",
            category: .documents,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "Keynote Presentation",
            extensions: [".key"],
            uti: "com.apple.iwork.keynote.key",
            category: .documents,
            icon: "chart.bar.doc.horizontal.fill"
        ),
        PresetFileType(
            displayName: "OpenDocument Spreadsheet",
            extensions: [".ods"],
            uti: "org.oasis-open.opendocument.spreadsheet",
            category: .documents,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "OpenDocument Presentation",
            extensions: [".odp"],
            uti: "org.oasis-open.opendocument.presentation",
            category: .documents,
            icon: "chart.bar.doc.horizontal.fill"
        ),
        PresetFileType(
            displayName: "Rich Text Bundle",
            extensions: [".rtfd"],
            uti: resolvedUTI(for: [".rtfd"], fallback: "public.rtf"),
            category: .documents,
            icon: "doc.richtext.fill"
        ),
        PresetFileType(
            displayName: "Comic Book Archive",
            extensions: [".cbz", ".cbr"],
            uti: resolvedUTI(for: [".cbz", ".cbr"], fallback: "public.data"),
            category: .documents,
            icon: "book.closed.fill"
        ),
        PresetFileType(
            displayName: "eBook (MOBI/AZW)",
            extensions: [".mobi", ".azw", ".azw3", ".fb2"],
            uti: resolvedUTI(for: [".mobi", ".azw3", ".fb2"], fallback: "public.data"),
            category: .documents,
            icon: "book.fill"
        ),
        PresetFileType(
            displayName: "DjVu Document",
            extensions: [".djvu", ".djv"],
            uti: resolvedUTI(for: [".djvu", ".djv"], fallback: "public.data"),
            category: .documents,
            icon: "doc.text.fill"
        ),
        PresetFileType(
            displayName: "XPS Document",
            extensions: [".xps"],
            uti: resolvedUTI(for: [".xps"], fallback: "public.data"),
            category: .documents,
            icon: "doc.text.fill"
        ),

        // 图片类
        PresetFileType(
            displayName: String(localized: "filetype_jpeg_image"),
            extensions: [".jpg", ".jpeg"],
            uti: "public.jpeg",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_png_image"),
            extensions: [".png"],
            uti: "public.png",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_gif_image"),
            extensions: [".gif"],
            uti: "com.compuserve.gif",
            category: .images,
            icon: "photo.on.rectangle.angled"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_webp_image"),
            extensions: [".webp"],
            uti: "org.webmproject.webp",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_svg_image"),
            extensions: [".svg"],
            uti: "public.svg-image",
            category: .images,
            icon: "SquareCompactLayout"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_heic_image"),
            extensions: [".heic"],
            uti: "public.heic",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_photoshop_file"),
            extensions: [".psd"],
            uti: "com.adobe.photoshop-image",
            category: .images,
            icon: "photo.artframe"
        ),
        PresetFileType(
            displayName: "BMP Image",
            extensions: [".bmp"],
            uti: "com.microsoft.bmp",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: "TIFF Image",
            extensions: [".tif", ".tiff"],
            uti: "public.tiff",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: "ICO Icon",
            extensions: [".ico"],
            uti: "com.microsoft.ico",
            category: .images,
            icon: "app.fill"
        ),
        PresetFileType(
            displayName: "HEIF Image",
            extensions: [".heif"],
            uti: "public.heif",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: "AVIF Image",
            extensions: [".avif"],
            uti: "public.avif",
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: "RAW Camera Image",
            extensions: [".dng", ".cr2", ".cr3", ".nef", ".arw", ".orf", ".rw2", ".raf"],
            uti: resolvedUTI(for: [".dng", ".nef", ".cr2"], fallback: "public.camera-raw-image"),
            category: .images,
            icon: "camera.fill"
        ),
        PresetFileType(
            displayName: "Apple Icon Image",
            extensions: [".icns"],
            uti: resolvedUTI(for: [".icns"], fallback: "com.apple.icns"),
            category: .images,
            icon: "app.fill"
        ),
        PresetFileType(
            displayName: "JPEG 2000 Image",
            extensions: [".jp2", ".j2k"],
            uti: resolvedUTI(for: [".jp2", ".j2k"], fallback: "public.jpeg-2000"),
            category: .images,
            icon: "photo.fill"
        ),
        PresetFileType(
            displayName: "Targa Image",
            extensions: [".tga"],
            uti: resolvedUTI(for: [".tga"], fallback: "public.image"),
            category: .images,
            icon: "photo.fill"
        ),

        // 视频类
        PresetFileType(
            displayName: String(localized: "filetype_mp4_video"),
            extensions: [".mp4"],
            uti: "public.mpeg-4",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_mov_video"),
            extensions: [".mov"],
            uti: "com.apple.quicktime-movie",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_avi_video"),
            extensions: [".avi"],
            uti: "public.avi",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_mkv_video"),
            extensions: [".mkv"],
            uti: "org.matroska.mkv",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_webm_video"),
            extensions: [".webm"],
            uti: "org.webmproject.webm",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "M4V Video",
            extensions: [".m4v"],
            uti: "public.mpeg-4",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "MPEG Video",
            extensions: [".mpeg", ".mpg"],
            uti: "public.mpeg",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "3GP Video",
            extensions: [".3gp"],
            uti: "public.3gpp",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "WMV Video",
            extensions: [".wmv"],
            uti: "com.microsoft.windows-media-wmv",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "FLV Video",
            extensions: [".flv"],
            uti: "com.adobe.flash.video",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "OGV Video",
            extensions: [".ogv"],
            uti: "org.xiph.ogv",
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "MPEG-2 Transport Stream",
            extensions: [".ts"],
            uti: resolvedUTI(for: [".ts"], fallback: "public.mpeg-2-transport-stream"),
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "AVCHD Stream",
            extensions: [".m2ts", ".mts"],
            uti: resolvedUTI(for: [".m2ts", ".mts"], fallback: "public.avchd-mpeg-2-transport-stream"),
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "DVD VOB Video",
            extensions: [".vob"],
            uti: resolvedUTI(for: [".vob"], fallback: "public.movie"),
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "MXF Video",
            extensions: [".mxf"],
            uti: resolvedUTI(for: [".mxf"], fallback: "public.movie"),
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "RealMedia Video",
            extensions: [".rm", ".rmvb"],
            uti: resolvedUTI(for: [".rm", ".rmvb"], fallback: "public.movie"),
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "F4V Video",
            extensions: [".f4v"],
            uti: resolvedUTI(for: [".f4v"], fallback: "com.adobe.flash.video"),
            category: .videos,
            icon: "video.fill"
        ),
        PresetFileType(
            displayName: "DV Video",
            extensions: [".dv"],
            uti: resolvedUTI(for: [".dv"], fallback: "public.dv-movie"),
            category: .videos,
            icon: "video.fill"
        ),

        // 音频类
        PresetFileType(
            displayName: String(localized: "filetype_mp3_audio"),
            extensions: [".mp3"],
            uti: "public.mp3",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_aac_audio"),
            extensions: [".aac", ".m4a"],
            uti: "public.aac-audio",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_flac_audio"),
            extensions: [".flac"],
            uti: "org.xiph.flac",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_wav_audio"),
            extensions: [".wav"],
            uti: "com.microsoft.waveform-audio",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_ogg_audio"),
            extensions: [".ogg"],
            uti: "org.xiph.ogg-audio",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "AIFF Audio",
            extensions: [".aiff", ".aif"],
            uti: "public.aiff-audio",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "WMA Audio",
            extensions: [".wma"],
            uti: "com.microsoft.windows-media-wma",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "Opus Audio",
            extensions: [".opus"],
            uti: "org.xiph.opus",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "AMR Audio",
            extensions: [".amr"],
            uti: "org.3gpp.adaptive-multi-rate-audio",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "MIDI Audio",
            extensions: [".mid", ".midi"],
            uti: "public.midi-audio",
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "Apple Lossless Audio",
            extensions: [".alac"],
            uti: resolvedUTI(for: [".alac"], fallback: "public.audio"),
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "APE Audio",
            extensions: [".ape"],
            uti: resolvedUTI(for: [".ape"], fallback: "public.audio"),
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "Core Audio Format",
            extensions: [".caf"],
            uti: resolvedUTI(for: [".caf"], fallback: "public.audio"),
            category: .audio,
            icon: "waveform"
        ),
        PresetFileType(
            displayName: "Audiobook",
            extensions: [".m4b"],
            uti: resolvedUTI(for: [".m4b"], fallback: "public.audio"),
            category: .audio,
            icon: "headphones"
        ),
        PresetFileType(
            displayName: "M3U Playlist",
            extensions: [".m3u"],
            uti: resolvedUTI(for: [".m3u"], fallback: "public.text"),
            category: .audio,
            icon: "music.note.list"
        ),
        PresetFileType(
            displayName: "M3U8 Playlist",
            extensions: [".m3u8"],
            uti: resolvedUTI(for: [".m3u8"], fallback: "public.text"),
            category: .audio,
            icon: "music.note.list"
        ),
        PresetFileType(
            displayName: "PLS Playlist",
            extensions: [".pls"],
            uti: resolvedUTI(for: [".pls"], fallback: "public.text"),
            category: .audio,
            icon: "music.note.list"
        ),
        PresetFileType(
            displayName: "XSPF Playlist",
            extensions: [".xspf"],
            uti: resolvedUTI(for: [".xspf"], fallback: "public.xml"),
            category: .audio,
            icon: "music.note.list"
        ),
        PresetFileType(
            displayName: "Web Audio",
            extensions: [".weba"],
            uti: resolvedUTI(for: [".weba"], fallback: "public.audio"),
            category: .audio,
            icon: "waveform"
        ),

        // 压缩包类
        PresetFileType(
            displayName: String(localized: "filetype_zip_archive"),
            extensions: [".zip"],
            uti: "public.zip-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_rar_archive"),
            extensions: [".rar"],
            uti: "com.rarlab.rar-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_7z_archive"),
            extensions: [".7z"],
            uti: "org.7-zip.7-zip-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_tar_archive"),
            extensions: [".tar"],
            uti: "public.tar-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_gz_archive"),
            extensions: [".gz", ".tar.gz"],
            uti: "org.gnu.gnu-zip-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: "BZip2 Archive",
            extensions: [".bz2", ".tar.bz2"],
            uti: "public.bzip2-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: "XZ Archive",
            extensions: [".xz", ".tar.xz"],
            uti: "org.tukaani.xz-archive",
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: "ISO Disk Image",
            extensions: [".iso"],
            uti: "public.iso-image",
            category: .archives,
            icon: "opticaldiscdrive.fill"
        ),
        PresetFileType(
            displayName: "DMG Disk Image",
            extensions: [".dmg"],
            uti: "com.apple.disk-image-udif",
            category: .archives,
            icon: "externaldrive.fill.badge.plus"
        ),
        PresetFileType(
            displayName: "Zstandard Archive",
            extensions: [".zst"],
            uti: resolvedUTI(for: [".zst"], fallback: "public.data"),
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: "LZMA Archive",
            extensions: [".lzma"],
            uti: resolvedUTI(for: [".lzma"], fallback: "public.data"),
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: "CAB Archive",
            extensions: [".cab"],
            uti: resolvedUTI(for: [".cab"], fallback: "public.data"),
            category: .archives,
            icon: "archivebox.fill"
        ),
        PresetFileType(
            displayName: "macOS Installer Package",
            extensions: [".pkg"],
            uti: resolvedUTI(for: [".pkg"], fallback: "com.apple.installer-package-archive"),
            category: .archives,
            icon: "shippingbox.fill"
        ),
        PresetFileType(
            displayName: "Windows Installer",
            extensions: [".msi"],
            uti: resolvedUTI(for: [".msi"], fallback: "com.microsoft.msi-installer"),
            category: .archives,
            icon: "shippingbox.fill"
        ),
        PresetFileType(
            displayName: "Debian Package",
            extensions: [".deb"],
            uti: resolvedUTI(for: [".deb"], fallback: "public.data"),
            category: .archives,
            icon: "shippingbox.fill"
        ),
        PresetFileType(
            displayName: "RPM Package",
            extensions: [".rpm"],
            uti: resolvedUTI(for: [".rpm"], fallback: "public.data"),
            category: .archives,
            icon: "shippingbox.fill"
        ),
        PresetFileType(
            displayName: "Android Package",
            extensions: [".apk"],
            uti: resolvedUTI(for: [".apk"], fallback: "public.archive"),
            category: .archives,
            icon: "shippingbox.fill"
        ),
        PresetFileType(
            displayName: "iOS App Archive",
            extensions: [".ipa"],
            uti: resolvedUTI(for: [".ipa"], fallback: "public.archive"),
            category: .archives,
            icon: "shippingbox.fill"
        ),

        // 代码类
        PresetFileType(
            displayName: String(localized: "filetype_swift_code"),
            extensions: [".swift"],
            uti: "public.swift-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_python_code"),
            extensions: [".py"],
            uti: "public.python-script",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_javascript_code"),
            extensions: [".js"],
            uti: "com.netscape.javascript-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_typescript_code"),
            extensions: [".ts"],
            uti: "public.typescript-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_html_file"),
            extensions: [".html", ".htm"],
            uti: "public.html",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_css_stylesheet"),
            extensions: [".css"],
            uti: "public.css",
            category: .code,
            icon: "paintbrush.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_java_code"),
            extensions: [".java"],
            uti: "com.sun.java-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_c_cpp_code"),
            extensions: [".c", ".cpp", ".h", ".hpp"],
            uti: "public.c-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Shell Script",
            extensions: [".sh", ".bash", ".zsh"],
            uti: "public.shell-script",
            category: .code,
            icon: "terminal.fill"
        ),
        PresetFileType(
            displayName: "Ruby Script",
            extensions: [".rb"],
            uti: "public.ruby-script",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "PHP Script",
            extensions: [".php"],
            uti: "public.php-script",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Go Source",
            extensions: [".go"],
            uti: "public.go-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Rust Source",
            extensions: [".rs"],
            uti: "public.rust-source",
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "SQL Script",
            extensions: [".sql"],
            uti: "public.sql-script",
            category: .code,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "TSX Source",
            extensions: [".tsx"],
            uti: resolvedUTI(for: [".tsx"], fallback: "public.typescript-source"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "JSX Source",
            extensions: [".jsx"],
            uti: resolvedUTI(for: [".jsx"], fallback: "com.netscape.javascript-source"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Vue Component",
            extensions: [".vue"],
            uti: resolvedUTI(for: [".vue"], fallback: "public.source-code"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Svelte Component",
            extensions: [".svelte"],
            uti: resolvedUTI(for: [".svelte"], fallback: "public.source-code"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Kotlin Source",
            extensions: [".kt", ".kts"],
            uti: resolvedUTI(for: [".kt", ".kts"], fallback: "public.source-code"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "C# Source",
            extensions: [".cs"],
            uti: resolvedUTI(for: [".cs"], fallback: "public.source-code"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Dart Source",
            extensions: [".dart"],
            uti: resolvedUTI(for: [".dart"], fallback: "public.source-code"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Objective-C Source",
            extensions: [".m", ".mm"],
            uti: resolvedUTI(for: [".m", ".mm"], fallback: "public.source-code"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "PowerShell Script",
            extensions: [".ps1"],
            uti: resolvedUTI(for: [".ps1"], fallback: "public.shell-script"),
            category: .code,
            icon: "terminal.fill"
        ),
        PresetFileType(
            displayName: "Batch Script",
            extensions: [".bat", ".cmd"],
            uti: resolvedUTI(for: [".bat", ".cmd"], fallback: "public.plain-text"),
            category: .code,
            icon: "terminal.fill"
        ),
        PresetFileType(
            displayName: "R Script",
            extensions: [".r"],
            uti: resolvedUTI(for: [".r"], fallback: "public.script"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Lua Script",
            extensions: [".lua"],
            uti: resolvedUTI(for: [".lua"], fallback: "public.script"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Perl Script",
            extensions: [".pl"],
            uti: resolvedUTI(for: [".pl"], fallback: "public.script"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "JSON with Comments",
            extensions: [".jsonc"],
            uti: resolvedUTI(for: [".jsonc"], fallback: "public.json"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),
        PresetFileType(
            displayName: "Web App Manifest",
            extensions: [".webmanifest"],
            uti: resolvedUTI(for: [".webmanifest"], fallback: "public.json"),
            category: .code,
            icon: "chevron.left.forwardslash.chevron.right"
        ),

        // 数据类
        PresetFileType(
            displayName: String(localized: "filetype_json_data"),
            extensions: [".json"],
            uti: "public.json",
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_xml_data"),
            extensions: [".xml"],
            uti: "public.xml",
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_csv_data"),
            extensions: [".csv"],
            uti: "public.comma-separated-values-text",
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: String(localized: "filetype_yaml_data"),
            extensions: [".yaml", ".yml"],
            uti: "public.yaml",
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "TOML Data",
            extensions: [".toml"],
            uti: "public.toml",
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "INI Config",
            extensions: [".ini", ".cfg", ".conf"],
            uti: "public.ini",
            category: .data,
            icon: "slider.horizontal.3"
        ),
        PresetFileType(
            displayName: "Property List",
            extensions: [".plist"],
            uti: "com.apple.property-list",
            category: .data,
            icon: "list.bullet.rectangle.portrait"
        ),
        PresetFileType(
            displayName: "SQLite Database",
            extensions: [".sqlite", ".sqlite3", ".db"],
            uti: "public.database",
            category: .data,
            icon: "cylinder.split.1x2.fill"
        ),
        PresetFileType(
            displayName: "Log File",
            extensions: [".log"],
            uti: "public.log",
            category: .data,
            icon: "text.append"
        ),
        PresetFileType(
            displayName: "NDJSON Data",
            extensions: [".ndjson"],
            uti: resolvedUTI(for: [".ndjson"], fallback: "public.json"),
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "GeoJSON Data",
            extensions: [".geojson"],
            uti: resolvedUTI(for: [".geojson"], fallback: "public.json"),
            category: .data,
            icon: "globe.europe.africa.fill"
        ),
        PresetFileType(
            displayName: "Parquet Data",
            extensions: [".parquet"],
            uti: resolvedUTI(for: [".parquet"], fallback: "public.data"),
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "Avro Data",
            extensions: [".avro"],
            uti: resolvedUTI(for: [".avro"], fallback: "public.data"),
            category: .data,
            icon: "tablecells.fill"
        ),
        PresetFileType(
            displayName: "iCalendar",
            extensions: [".ics"],
            uti: resolvedUTI(for: [".ics"], fallback: "public.calendar-event"),
            category: .data,
            icon: "calendar"
        ),
        PresetFileType(
            displayName: "vCard Contact",
            extensions: [".vcf"],
            uti: resolvedUTI(for: [".vcf"], fallback: "public.vcard"),
            category: .data,
            icon: "person.text.rectangle"
        ),
        PresetFileType(
            displayName: "GPX Track",
            extensions: [".gpx"],
            uti: resolvedUTI(for: [".gpx"], fallback: "public.xml"),
            category: .data,
            icon: "point.topleft.down.curvedto.point.bottomright.up"
        ),
        PresetFileType(
            displayName: "KML Map Data",
            extensions: [".kml"],
            uti: resolvedUTI(for: [".kml"], fallback: "public.xml"),
            category: .data,
            icon: "map.fill"
        ),
        PresetFileType(
            displayName: "BitTorrent Metadata",
            extensions: [".torrent"],
            uti: resolvedUTI(for: [".torrent"], fallback: "org.bittorrent.torrent"),
            category: .data,
            icon: "arrow.down.circle.fill"
        ),
        PresetFileType(
            displayName: "Subtitle Files",
            extensions: [".srt", ".ass", ".ssa", ".sub", ".vtt"],
            uti: resolvedUTI(for: [".vtt", ".srt"], fallback: "public.plain-text"),
            category: .data,
            icon: "captions.bubble.fill"
        ),
        PresetFileType(
            displayName: "Certificate Files",
            extensions: [".pem", ".cer", ".crt", ".p12", ".pfx"],
            uti: resolvedUTI(for: [".pem", ".cer", ".p12"], fallback: "public.data"),
            category: .data,
            icon: "checkmark.shield.fill"
        ),
    ]

    // MARK: - 辅助方法

    private static func resolvedUTI(for extensions: [String], fallback: String = "public.data") -> String {
        for ext in extensions {
            let normalized = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
            guard !normalized.isEmpty else { continue }

            if let utType = UTType(filenameExtension: normalized) {
                return utType.identifier
            }
        }
        return fallback
    }

    /// 按分类组织文件类型
    static func typesByCategory() -> [Category: [PresetFileType]] {
        var result: [Category: [PresetFileType]] = [:]

        for category in Category.allCases {
            result[category] = allTypes.filter { $0.category == category }
        }

        return result
    }

    /// 查找文件类型
    static func find(extension ext: String) -> PresetFileType? {
        allTypes.first { $0.extensions.contains(ext.lowercased()) }
    }

    /// 查找文件类型
    static func find(uti: String) -> PresetFileType? {
        allTypes.first { $0.uti == uti }
    }
}
