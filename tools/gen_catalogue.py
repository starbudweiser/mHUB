#!/usr/bin/env python3
"""Génère Resources/catalogue.json (catalogue des applis du Mac Desktop Toolkit). Modifier ici, puis relancer."""
import json, os
G = ("Application du Mac Desktop Toolkit.", "Mac Desktop Toolkit app.", "Aplicación del Mac Desktop Toolkit.", "App del Mac Desktop Toolkit.")
# id, bundle, repo (None = pas encore publique), catégorie, (fr, en, es, it) ou None, réglages (None | {"url":..} | {"args":[..]})
A = [
 ("ARCHiVES","fr.stephan.archives","ARCHiVES","files",None,None),
 ("CAREERDeSK","com.starbudweiser.careerdesk",None,"comms",None,None),
 ("HORIZONs","com.starbudweiser.horizons",None,"comms",None,None),
 ("MAiLS","fr.stephan.mails",None,"comms",None,None),
 ("MiCONE","fr.stephan.micone","MiCONE","creative",("Transforme n'importe quelle image en icône macOS (.icns).","Turns any image into a macOS icon (.icns).","Convierte cualquier imagen en un icono de macOS (.icns).","Trasforma qualsiasi immagine in un'icona macOS (.icns)."),None),
 ("SOCiALS","fr.stephan.socials",None,"comms",None,None),
 ("TESSERaCT","fr.stephan.tesseract",None,"system",("Découvre et récupère des images de systèmes ARM64 (BSD, Linux…).","Discover and fetch ARM64 system images (BSD, Linux…).","Descubre y descarga imágenes de sistemas ARM64 (BSD, Linux…).","Scopri e scarica immagini di sistemi ARM64 (BSD, Linux…)."),None),
 ("hdCLEANER","com.stephan.hdcleaner","hdCLEANER","system",("Nettoyeur de disque : déchets, nettoyage système, désinstalleur d'applis, fichiers cachés.","Disk cleaner: junk, system cleanup, app uninstaller, hidden files.","Limpiador de disco: basura, limpieza del sistema, desinstalador de apps, archivos ocultos.","Pulitore del disco: rifiuti, pulizia del sistema, disinstallatore di app, file nascosti."),None),
 ("iCONIQ","fr.stephan.iconiq","iCONIQ","creative",("Bibliothèque d'icônes : fabrique et range les icônes d'applis et de dossiers.","Icon library: makes and files app and folder icons.","Biblioteca de iconos: crea y organiza iconos de apps y carpetas.","Libreria di icone: crea e organizza le icone di app e cartelle."),None),
 ("kYNEDIT","com.starbudweiser.kynedit",None,"creative",("Explorateur de médias et transcodeur pour monteurs.","Media explorer and transcoder for editors.","Explorador de medios y transcodificador para editores.","Esplora media e transcodifica per montatori."),None),
 ("mBACKUP","fr.stephan.mbackup","mBACKUP","files",("Copies miroir planifiées de vos dossiers, dans la barre des menus.","Scheduled mirror copies of your folders, in the menu bar.","Copias espejo programadas de tus carpetas, en la barra de menús.","Copie speculari pianificate delle tue cartelle, nella barra dei menu."),{"args":["--settings"]}),
 ("mCLEAN","com.stephan.mclean","mCLEAN","system",("Affiche la mémoire du Mac dans la barre des menus et la libère en un clic.","Shows your Mac's memory in the menu bar and frees it in one click.","Muestra la memoria del Mac en la barra de menús y la libera con un clic.","Mostra la memoria del Mac nella barra dei menu e la libera con un clic."),None),
 ("mCLOUD","fr.stephan.mcloud","mCLOUD","files",None,None),
 ("mDESK","com.stephan.mdesk","mDESK","system",("Mémorise et restaure la position des icônes du bureau et des fenêtres selon les écrans.","Remembers and restores desktop icon and window positions per display setup.","Recuerda y restaura la posición de los iconos del escritorio y las ventanas según las pantallas.","Memorizza e ripristina la posizione di icone e finestre in base agli schermi."),None),
 ("mFRAMES","fr.stephan.mframes",None,"creative",("Revue et annotation en direct entre prestataire et client : vidéo, photos, PDF, maquettes.","Live review and annotation between provider and client: video, photos, PDF, mockups.","Revisión y anotación en directo entre proveedor y cliente: vídeo, fotos, PDF, maquetas.","Revisione e annotazione dal vivo tra fornitore e cliente: video, foto, PDF, mockup."),None),
 ("mLINKS","fr.stephan.mlinks","mLINKS","system",("Applis, dossiers, fichiers et liens web à un clic dans la barre des menus.","Your apps, folders, files and web links one click away in the menu bar.","Tus apps, carpetas, archivos y enlaces web a un clic en la barra de menús.","App, cartelle, file e link web a un clic nella barra dei menu."),None),
 ("mPARLE","fr.stephan.mparle","mPARLE","ai",("Traduction rapide de tout texte sélectionné, gratuite et locale d'abord.","Fast translation of any selected text, free and local first.","Traducción rápida de cualquier texto seleccionado, gratuita y local primero.","Traduzione rapida di qualsiasi testo selezionato, gratuita e locale prima di tutto."),None),
 ("mPASTE","fr.stephan.mpaste",None,"system",None,None),
 ("mPDF","fr.stephan.mpdf","mPDF","files",("Lecteur et éditeur de PDF rapide et léger.","A fast, lightweight PDF reader and editor.","Lector y editor de PDF rápido y ligero.","Lettore ed editor di PDF veloce e leggero."),None),
 ("mPIE","fr.stephan.mpie",None,"system",None,None),
 ("mSILENCE","fr.stephan.msilence","mSILENCE","system",("Pare-feu par appli et moniteur réseau personnels.","Personal per-app firewall and network monitor.","Cortafuegos por app y monitor de red personales.","Firewall per app e monitor di rete personali."),None),
 ("mSIZER","fr.stephan.msizer","mSIZER","creative",("Retouche de photos par lots : redimensionner, recadrer, filigrane, convertir.","Batch photo editor: resize, crop, watermark, convert.","Edición de fotos por lotes: redimensionar, recortar, marca de agua, convertir.","Ritocco foto in blocco: ridimensiona, ritaglia, filigrana, converti."),None),
 ("mSPACES","com.starbudweiser.mspaces","mSPACES","system",("Organise les icônes de la barre des menus en groupes grâce à des séparateurs.","Organize your menu bar items into groups with separators.","Organiza los iconos de la barra de menús en grupos con separadores.","Organizza le icone della barra dei menu in gruppi con separatori."),None),
 ("mSTAGRAM","fr.stephan.mstagram","mSTAGRAM","comms",("Instagram en version téléphone, dans une fenêtre sur le Mac.","Instagram in its phone version, in a window on your Mac.","Instagram en versión móvil, en una ventana del Mac.","Instagram in versione telefono, in una finestra sul Mac."),None),
 ("mSTICK","fr.stephan.mstick","mSTICK","system",None,None),
 ("mTAB","fr.stephan.mtab","mTAB","system",None,None),
 ("mTAPES","fr.stephan.mtapes","mTAPES","creative",("Enregistreur d'écran natif avec montage automatique, piloté par n'importe quelle IA via MCP.","Native screen recorder with automatic editing, driven by any AI through MCP.","Grabador de pantalla nativo con edición automática, controlado por cualquier IA mediante MCP.","Registratore di schermo nativo con montaggio automatico, pilotato da qualsiasi IA tramite MCP."),None),
 ("mUGGINFACE","fr.stephan.mugginface",None,"ai",("Les meilleurs modèles d'IA de Hugging Face, adaptés à ton Mac, avec veille constante.","The best Hugging Face AI models for your Mac, with constant monitoring.","Los mejores modelos de IA de Hugging Face, adaptados a tu Mac, con vigilancia constante.","I migliori modelli di IA di Hugging Face, adatti al tuo Mac, con monitoraggio costante."),None),
 ("qLOOKS","fr.stephan.alphalook","qLOOKS","creative",("Aperçus et vignettes Quick Look pour les formats que macOS ne gère pas.","Quick Look previews and thumbnails for formats macOS does not handle.","Vistas previas y miniaturas Quick Look para formatos que macOS no gestiona.","Anteprime e miniature Quick Look per i formati che macOS non gestisce."),None),
 ("qNOTES","fr.stephan.qnotes","qNOTES","files",None,None),
 ("wCLAUDE","fr.stephan.wclaude","wCLAUDE","ai",("Navigateur macOS que n'importe quelle IA compatible MCP peut piloter entièrement.","A macOS browser any MCP-compatible AI agent can fully drive.","Navegador de macOS que cualquier IA compatible con MCP puede controlar por completo.","Browser per macOS che qualsiasi IA compatibile con MCP può pilotare del tutto."),None),
]
out = {"version": 1, "teamID": "35KLMK53PN", "owner": "starbudweiser", "apps": []}
for id_, bid, repo, cat, d, st in A:
    d = d or G
    e = {"id": id_, "name": id_, "bundleId": bid, "category": cat,
         "desc": dict(zip(("fr","en","es","it"), d))}
    if repo: e["repo"] = repo
    if st: e["settings"] = st
    out["apps"].append(e)
path = os.path.join(os.path.dirname(__file__), "..", "Resources", "catalogue.json")
json.dump(out, open(path, "w"), ensure_ascii=False, indent=1)
print(len(out["apps"]), "applis")
