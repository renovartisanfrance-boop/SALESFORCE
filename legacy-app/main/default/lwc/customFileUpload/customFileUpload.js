import { LightningElement, api, track } from 'lwc';
import uploadFile from '@salesforce/apex/CustomFileUploadController.uploadFile';
import uploadMultipleFiles from '@salesforce/apex/CustomFileUploadController.uploadMultipleFiles';
// Traduction FR/ES partagée — voir c/lwc000_i18n
import { FR, etiquettes, remplir } from 'c/lwc000_i18n';

export default class CustomFileUpload extends LightningElement {
    // Public properties
    @api label;
    @api buttonLabel = 'Choisir un fichier';
    @api acceptedFormats = ''; // e.g., '.pdf,.jpg,.png'
    @api maxFileSize = 4500000; // Default ~4.5MB (safe for guest users)
    @api required = false;
    @api disabled = false;
    @api multiple = false;
    @api showFileInfo;
    @api recordId; // Optional: if you want to link immediately
    @api useBatchUpload = false; // If true, uploads all files in one API call (faster but no progress tracking)
    @api maxTotalSize = 0; // Max total size for all files combined (0 = no limit)

    // --- Compression d'images côté navigateur (opt-in) ---------------------
    // Les photos de smartphone pèsent 2 à 5 Mo pièce, alors que tout le payload
    // part en base64 dans un seul appel Apex synchrone (heap 6 Mo). Sans
    // compression, une seule photo sature la limite. Redimensionnées à 1600px
    // en JPEG q=0.72, elles retombent à ~150-350 Ko sans perte de lisibilité.
    // Désactivé par défaut : ce composant est partagé, rien ne change ailleurs.
    @api compresserImages = false;
    @api dimensionMax = 1600;   // plus grand côté, en pixels
    @api qualiteJpeg = 0.72;    // 0 à 1
    @api seuilCompression = 300000; // en-deçà, l'image est laissée telle quelle

    // Variante compacte : zone de dépôt réduite à une carte, sans liste interne
    // ni bloc « taille totale ». Utilisée quand plusieurs zones cohabitent sur
    // une ligne et que le parent affiche un récapitulatif global.
    @api compact = false;

    // Langue d'affichage, poussée par le composant parent. Composant partagé :
    // sans cette propriété il reste en français, comme aujourd'hui.
    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || FR;
    }

    get txt() {
        return etiquettes('fileUpload', this._langue);
    }

    // Progression et succès : interpolés ici et non dans le template, car
    // l'espagnol place « ¡ » avant le nombre.
    get texteProgression() {
        return this.multiple
            ? remplir(this.txt.telechargementPourcent, { pct: this.uploadProgress })
            : this.txt.telechargementEnCours;
    }

    get texteSucces() {
        return this.multiple
            ? remplir(this.txt.fichiersTelecharges, { n: this.uploadedFilesCount })
            : this.txt.fichierTelecharge;
    }

    // Internal properties
    fileName = '';
    fileSize = '';
    isUploading = false;
    uploadSuccess = false;
    errorMessage = '';
    fileData = null;
    uploadedContentDocumentId = null;

    // Multiple files support
    @track selectedFiles = [];
    uploadedFiles = [];
    uploadProgress = 0;

    // Drag & Drop state
    isDragging = false;
    fileIdCounter = 0;

    // Getters
    get progressBarStyle() {
        return `width: ${this.uploadProgress}%`;
    }

    get uploadedFilesCount() {
        return this.uploadedFiles.length;
    }

    get dropZoneClass() {
        let baseClass = 'drop-zone';
        if (this.isDragging) {
            baseClass += ' drop-zone-active';
        }
        if (this.disabled) {
            baseClass += ' drop-zone-disabled';
        }
        return baseClass;
    }

    get hasSelectedFiles() {
        return this.selectedFiles.length > 0;
    }

    get selectedFilesCount() {
        return this.selectedFiles.length;
    }

    get selectedFilesDisplay() {
        return this.selectedFiles.map(file => ({
            ...file,
            formattedSize: this.formatFileSize(file.size)
        }));
    }

    get totalFileSize() {
        if (this.selectedFiles.length === 0) return '';
        const total = this.selectedFiles.reduce((sum, file) => sum + file.size, 0);
        return this.formatFileSize(total);
    }

    // --- Variante compacte --------------------------------------------------
    get modeNormal() {
        return !this.compact;
    }

    /**
     * Libellé rendu AU-DESSUS de la zone : mode normal uniquement.
     * La carte compacte porte déjà le libellé ; sans cette condition, le nom du
     * type apparaissait deux fois de suite (constaté sur c/lwc026_documents et
     * sur les sections de photos de c/lwc020_NouveauRdv).
     */
    get afficherLabelSepare() {
        return !this.compact && !!this.label;
    }

    // En compact, la liste et le total sont rendus par le parent (récap global).
    get afficherListeInterne() {
        return !this.compact && this.hasSelectedFiles;
    }

    get afficherInfoTaille() {
        return !this.compact && this.showFileInfo && !!this.totalFileSize;
    }

    /** Sous-titre de la carte compacte : « Ajouter » ou « 2 fichiers ». */
    get resumeCompact() {
        const n = this.selectedFiles.length;
        if (n === 0) return this.txt.ajouter;
        return remplir(n === 1 ? this.txt.unFichier : this.txt.nFichiers, { n });
    }

    get carteCompacteClass() {
        let c = 'zone-compacte';
        if (this.selectedFiles.length > 0) c += ' zone-compacte--remplie';
        if (this.isDragging) c += ' zone-compacte--survol';
        if (this.disabled) c += ' zone-compacte--inactive';
        return c;
    }

    // Drag & Drop handlers
    handleDragOver(event) {
        event.preventDefault();
        event.stopPropagation();
        if (!this.disabled) {
            this.isDragging = true;
        }
    }

    handleDragLeave(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragging = false;
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        this.isDragging = false;

        if (this.disabled) return;

        const files = Array.from(event.dataTransfer.files);
        if (files.length > 0) {
            this.processFiles(files);
        }
    }

    // Handle file input trigger
    triggerFileInput(event) {
        event.stopPropagation();
        const fileInput = this.template.querySelector('.file-input');
        if (fileInput && !this.disabled) {
            fileInput.click();
        }
    }

    // Handle file selection from input
    handleFileChange(event) {
        const files = Array.from(event.target.files);
        if (files.length > 0) {
            this.processFiles(files);
        }
        // Reset input to allow selecting the same file again
        event.target.value = '';
    }

    /**
     * Redimensionne et recompresse une image avant toute validation de taille.
     * Renvoie TOUJOURS un fichier exploitable : en cas d'échec (format exotique,
     * canvas indisponible) on retourne l'original plutôt que de perdre la photo.
     */
    async compresserImage(fichier) {
        if (!this.compresserImages) return fichier;
        if (!fichier.type || fichier.type.indexOf('image/') !== 0) return fichier;
        // Un GIF animé perdrait son animation, un SVG est déjà minuscule.
        if (fichier.type === 'image/gif' || fichier.type === 'image/svg+xml') return fichier;
        if (fichier.size <= this.seuilCompression) return fichier;

        try {
            const bitmap = await createImageBitmap(fichier);
            const ratio = Math.min(1, this.dimensionMax / Math.max(bitmap.width, bitmap.height));
            const largeur = Math.round(bitmap.width * ratio);
            const hauteur = Math.round(bitmap.height * ratio);

            const canvas = document.createElement('canvas');
            canvas.width = largeur;
            canvas.height = hauteur;
            const ctx = canvas.getContext('2d');
            // Fond blanc : un PNG transparent converti en JPEG deviendrait noir.
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(0, 0, largeur, hauteur);
            ctx.drawImage(bitmap, 0, 0, largeur, hauteur);
            if (bitmap.close) bitmap.close();

            const blob = await new Promise(res => canvas.toBlob(res, 'image/jpeg', this.qualiteJpeg));
            // Si la compression n'apporte rien, on garde l'original.
            if (!blob || blob.size >= fichier.size) return fichier;

            const nomSansExt = fichier.name.replace(/\.[^.]+$/, '');
            return new File([blob], nomSansExt + '.jpg', { type: 'image/jpeg' });
        } catch (e) {
            console.warn('Compression impossible, fichier original conservé:', fichier.name, e);
            return fichier;
        }
    }

    // Process files (from input or drag & drop)
    // async : la compression doit précéder la validation de taille, sinon une
    // photo de 5 Mo serait rejetée avant même d'avoir pu être réduite.
    async processFiles(fichiersEntrants) {
        // Reset error states
        this.errorMessage = '';
        this.uploadSuccess = false;

        let files;
        try {
            files = await Promise.all(fichiersEntrants.map(f => this.compresserImage(f)));
        } catch (e) {
            console.warn('Compression globale impossible, fichiers originaux conservés:', e);
            files = fichiersEntrants;
        }

        const validFiles = [];

        for (const file of files) {
            // Check if file already exists (by name and size)
            const isDuplicate = this.selectedFiles.some(
                existing => existing.fileName === file.name && existing.size === file.size
            );

            if (isDuplicate) {
                continue; // Skip duplicate files
            }

            // Validate file size
            if (file.size > this.maxFileSize) {
                this.errorMessage = remplir(this.txt.errFichierVolumineux, { nom: file.name, max: this.formatFileSize(this.maxFileSize) });
                continue;
            }

            // Validate file type if acceptedFormats is specified
            if (this.acceptedFormats) {
                const fileExtension = '.' + file.name.split('.').pop().toLowerCase();
                const acceptedExtensions = this.acceptedFormats.toLowerCase().split(',').map(ext => ext.trim());

                if (!acceptedExtensions.includes(fileExtension)) {
                    this.errorMessage = remplir(this.txt.errTypeNonAutorise, { nom: file.name, formats: this.acceptedFormats });
                    continue;
                }
            }

            validFiles.push(file);
        }

        // Check total size limit
        if (this.maxTotalSize > 0 && validFiles.length > 0) {
            const currentTotal = this.selectedFiles.reduce((sum, f) => sum + f.size, 0);
            const newFilesTotal = validFiles.reduce((sum, f) => sum + f.size, 0);
            if (currentTotal + newFilesTotal > this.maxTotalSize) {
                this.errorMessage = remplir(this.txt.errTailleTotale, {
                    max: this.formatFileSize(this.maxTotalSize),
                    actuelle: this.formatFileSize(currentTotal + newFilesTotal)
                });
                return;
            }
        }

        if (validFiles.length > 0) {
            this.readFilesAsBase64(validFiles);
        }
    }

    // Read multiple files and convert to base64
    async readFilesAsBase64(files) {
        try {
            const fileDataPromises = files.map(file => this.readSingleFileAsBase64(file));
            const newFiles = await Promise.all(fileDataPromises);

            // Add unique IDs to new files
            const filesWithIds = newFiles.map(file => ({
                ...file,
                id: `file-${++this.fileIdCounter}`
            }));

            // Append to existing files (allow adding more files)
            this.selectedFiles = [...this.selectedFiles, ...filesWithIds];

            // Update display info
            this.updateFileInfo();

            // For backward compatibility with single file mode
            if (this.selectedFiles.length > 0) {
                this.fileData = this.selectedFiles[0];
            }

            // Dispatch event to notify parent about file selection change
            this.dispatchEvent(new CustomEvent('fileschange', {
                detail: {
                    files: this.selectedFiles,
                    count: this.selectedFiles.length
                }
            }));
        } catch (error) {
            this.errorMessage = this.txt.errLecture;
            console.error('Error reading files:', error);
        }
    }

    // Read single file and convert to base64
    readSingleFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();

            reader.onload = () => {
                const base64 = reader.result.split(',')[1]; // Remove data:... prefix
                resolve({
                    fileName: file.name,
                    base64: base64,
                    contentType: file.type || 'application/octet-stream',
                    size: file.size
                });
            };

            reader.onerror = () => {
                reject(new Error(`Erreur lors de la lecture du fichier: ${file.name}`));
            };

            reader.readAsDataURL(file);
        });
    }

    // Update file info display
    updateFileInfo() {
        if (this.selectedFiles.length === 0) {
            this.fileName = '';
            this.fileSize = '';
        } else if (this.selectedFiles.length === 1) {
            this.fileName = this.selectedFiles[0].fileName;
            this.fileSize = this.formatFileSize(this.selectedFiles[0].size);
        } else {
            this.fileName = `${this.selectedFiles.length} fichier(s) sélectionné(s)`;
            const totalSize = this.selectedFiles.reduce((sum, file) => sum + file.size, 0);
            this.fileSize = this.formatFileSize(totalSize);
        }
    }

    // Handle remove file button click
    /**
     * Suppression pilotée par le parent (récapitulatif global des pièces jointes).
     * Même effet qu'un clic sur la croix de la liste interne.
     */
    @api
    supprimerFichier(fileId) {
        this.handleRemoveFile({ currentTarget: { dataset: { fileId } } });
    }

    handleRemoveFile(event) {
        const fileId = event.currentTarget.dataset.fileId;
        this.selectedFiles = this.selectedFiles.filter(file => file.id !== fileId);

        // Update display info
        this.updateFileInfo();

        // Update fileData for backward compatibility
        if (this.selectedFiles.length > 0) {
            this.fileData = this.selectedFiles[0];
        } else {
            this.fileData = null;
        }

        // Clear success/error messages
        this.uploadSuccess = false;
        this.errorMessage = '';

        // Dispatch event to notify parent about file removal
        this.dispatchEvent(new CustomEvent('fileschange', {
            detail: {
                files: this.selectedFiles,
                count: this.selectedFiles.length
            }
        }));
    }

    // Clear all files
    clearAllFiles() {
        this.selectedFiles = [];
        this.fileData = null;
        this.fileName = '';
        this.fileSize = '';
        this.uploadSuccess = false;
        this.errorMessage = '';
        this.uploadedFiles = [];
        this.uploadedContentDocumentId = null;

        // Dispatch event to notify parent
        this.dispatchEvent(new CustomEvent('fileschange', {
            detail: {
                files: [],
                count: 0
            }
        }));
    }

    // Public method to trigger upload
    @api
    async uploadFileToSalesforce() {
        // Handle multiple files
        if (this.multiple && this.selectedFiles.length > 0) {
            return await this.uploadMultipleFilesMethod();
        }

        // Handle single file
        if (!this.fileData) {
            this.errorMessage = this.txt.errSelectionFichier;
            return null;
        }

        this.isUploading = true;
        this.errorMessage = '';
        this.uploadSuccess = false;

        try {
            const result = await uploadFile({
                fileName: this.fileData.fileName,
                base64Data: this.fileData.base64,
                contentType: this.fileData.contentType,
                recordId: this.recordId
            });

            console.log('Upload result:', result);

            this.uploadedContentDocumentId = result.contentDocumentId;
            this.uploadSuccess = true;
            this.isUploading = false;

            // Dispatch event to parent component
            this.dispatchEvent(new CustomEvent('uploadsuccess', {
                detail: {
                    contentDocumentId: result.contentDocumentId,
                    contentVersionId: result.contentVersionId,
                    contentDocumentLinkId: result.contentDocumentLinkId,
                    fileName: this.fileData.fileName
                }
            }));

            return result;

        } catch (error) {
            this.isUploading = false;
            this.uploadSuccess = false;
            this.errorMessage = error.body?.message || this.txt.errTelechargementFichier;

            // Dispatch error event
            this.dispatchEvent(new CustomEvent('uploaderror', {
                detail: {
                    error: this.errorMessage
                }
            }));

            console.error('Upload error:', error);
            return null;
        }
    }

    // Upload multiple files
    async uploadMultipleFilesMethod() {
        if (!this.selectedFiles || this.selectedFiles.length === 0) {
            this.errorMessage = this.txt.errSelectionAuMoinsUn;
            return null;
        }

        // Use batch upload if enabled
        if (this.useBatchUpload) {
            return await this.uploadMultipleFilesBatch();
        }

        // Sequential upload with progress tracking
        this.isUploading = true;
        this.errorMessage = '';
        this.uploadSuccess = false;
        this.uploadedFiles = [];
        this.uploadProgress = 0;

        const results = [];
        const errors = [];

        try {
            for (let i = 0; i < this.selectedFiles.length; i++) {
                const fileData = this.selectedFiles[i];
                this.uploadProgress = Math.round(((i + 1) / this.selectedFiles.length) * 100);

                try {
                    const result = await uploadFile({
                        fileName: fileData.fileName,
                        base64Data: fileData.base64,
                        contentType: fileData.contentType,
                        recordId: this.recordId
                    });

                    console.log(`Upload result for ${fileData.fileName}:`, result);

                    this.uploadedFiles.push({
                        ...result,
                        fileName: fileData.fileName
                    });

                    results.push(result);

                } catch (error) {
                    console.error(`Upload error for ${fileData.fileName}:`, error);
                    errors.push({
                        fileName: fileData.fileName,
                        error: error.body?.message || error.message
                    });
                }
            }

            this.isUploading = false;

            // Set success if at least one file uploaded
            if (results.length > 0) {
                this.uploadSuccess = true;

                // Dispatch success event with all results
                this.dispatchEvent(new CustomEvent('uploadsuccess', {
                    detail: {
                        files: this.uploadedFiles,
                        totalFiles: this.selectedFiles.length,
                        successCount: results.length,
                        errorCount: errors.length
                    }
                }));
            }

            // Set error message if any uploads failed
            if (errors.length > 0) {
                const failedFiles = errors.map(e => e.fileName).join(', ');
                this.errorMessage = remplir(this.txt.errEchecTelechargement, { n: errors.length, fichiers: failedFiles });

                // Dispatch error event
                this.dispatchEvent(new CustomEvent('uploaderror', {
                    detail: {
                        errors: errors,
                        successCount: results.length
                    }
                }));
            }

            return {
                success: results,
                errors: errors,
                totalFiles: this.selectedFiles.length
            };

        } catch (error) {
            this.isUploading = false;
            this.uploadSuccess = false;
            this.errorMessage = this.txt.errTelechargementFichiers;

            console.error('Upload error:', error);
            return null;
        }
    }

    // Upload multiple files in batch (single API call)
    async uploadMultipleFilesBatch() {
        this.isUploading = true;
        this.errorMessage = '';
        this.uploadSuccess = false;
        this.uploadedFiles = [];
        this.uploadProgress = 50; // Show 50% since we can't track individual progress

        try {
            // Prepare files data for batch upload
            const filesData = this.selectedFiles.map(file => ({
                fileName: file.fileName,
                base64: file.base64,
                contentType: file.contentType
            }));

            const results = await uploadMultipleFiles({
                filesData: JSON.stringify(filesData),
                recordId: this.recordId
            });

            console.log('Batch upload results:', results);

            this.uploadProgress = 100;

            const successResults = [];
            const errors = [];

            // Process results
            results.forEach(result => {
                if (result.success) {
                    this.uploadedFiles.push(result);
                    successResults.push(result);
                } else {
                    errors.push({
                        fileName: result.fileName,
                        error: result.error
                    });
                }
            });

            this.isUploading = false;

            // Set success if at least one file uploaded
            if (successResults.length > 0) {
                this.uploadSuccess = true;

                // Dispatch success event
                this.dispatchEvent(new CustomEvent('uploadsuccess', {
                    detail: {
                        files: this.uploadedFiles,
                        totalFiles: this.selectedFiles.length,
                        successCount: successResults.length,
                        errorCount: errors.length
                    }
                }));
            }

            // Set error message if any uploads failed
            if (errors.length > 0) {
                const failedFiles = errors.map(e => e.fileName).join(', ');
                this.errorMessage = remplir(this.txt.errEchecTelechargement, { n: errors.length, fichiers: failedFiles });

                // Dispatch error event
                this.dispatchEvent(new CustomEvent('uploaderror', {
                    detail: {
                        errors: errors,
                        successCount: successResults.length
                    }
                }));
            }

            return {
                success: successResults,
                errors: errors,
                totalFiles: this.selectedFiles.length
            };

        } catch (error) {
            this.isUploading = false;
            this.uploadSuccess = false;
            this.errorMessage = error.body?.message || this.txt.errTelechargementFichiers;

            // Dispatch error event
            this.dispatchEvent(new CustomEvent('uploaderror', {
                detail: {
                    error: this.errorMessage
                }
            }));

            console.error('Batch upload error:', error);
            return null;
        }
    }

    // Public method to get file data without uploading
    @api
    getFileData() {
        // Return multiple files if in multiple mode
        if (this.multiple && this.selectedFiles.length > 0) {
            return this.selectedFiles.map(file => ({
                // id exposé pour que le parent puisse cibler une suppression
                // depuis son récapitulatif global.
                id: file.id,
                fileName: file.fileName,
                base64: file.base64,
                contentType: file.contentType,
                size: file.size
            }));
        }

        // Return single file
        if (!this.fileData) {
            return null;
        }
        return {
            fileName: this.fileData.fileName,
            base64: this.fileData.base64,
            contentType: this.fileData.contentType,
            size: this.fileSize
        };
    }

    // Public method to check if file is selected
    @api
    hasFile() {
        if (this.multiple) {
            return this.selectedFiles.length > 0;
        }
        return this.fileData !== null;
    }

    // Public method to get uploaded ContentDocumentId(s)
    @api
    getContentDocumentId() {
        if (this.multiple && this.uploadedFiles.length > 0) {
            return this.uploadedFiles.map(file => file.contentDocumentId);
        }
        return this.uploadedContentDocumentId;
    }

    // Public method to get all uploaded files info
    @api
    getUploadedFiles() {
        return this.uploadedFiles;
    }

    // Public method to get total size of selected files
    @api
    getTotalFileSize() {
        return this.selectedFiles.reduce((sum, f) => sum + f.size, 0);
    }

    // Public method to reset the component
    @api
    reset() {
        this.resetFileInput();
        this.errorMessage = '';
        this.uploadSuccess = false;
        this.uploadedContentDocumentId = null;
        this.selectedFiles = [];
        this.uploadedFiles = [];
        this.uploadProgress = 0;
        this.isDragging = false;
    }

    // Helper: Reset file input
    resetFileInput() {
        this.fileName = '';
        this.fileSize = '';
        this.fileData = null;
        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    // Helper: Format file size
    formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }
}