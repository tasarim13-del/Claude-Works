/*
================================================================================
  PRO Batch v0.2  -  Sahnedeki tum kameralari sirayla render eden gece paneli
  Hedef: 3ds Max 2024+ / V-Ray (tum render motorlariyla calisir)
================================================================================
  KULLANIM
  - Scripting > Run Script... > ProBatch.ms
  - Panel sahnedeki tum kameralari bulur (V-Ray Physical, Physical,
    Target/Free kamera vb.). Render edilecekleri secin.
  - Once "Hizli Test" ile tek kamerayi %25 cozunurlukte deneyin.
  - Sonra "TUM SECILI KAMERALARI RENDER ET" deyin ve makineyi birakin.

  GECE MODU
  - Hata veren kamera atlanir, kuyruk devam eder.
  - Cikti klasorune PRO_Batch_rapor.txt yazilir (sure, hata, dosya).
  - Istege bagli: is bitince bilgisayar 5 dk sonra kapanir.
    (Iptal icin: Baslat > Calistir > shutdown /a)
  - Render ayarlari: aktif Render Setup (V-Ray dahil) aynen kullanilir;
    her kamera F9 ile ayni yoldan render edilir.
  - Kayit: V-Ray kullaniliyorsa goruntu V-Ray VFB'den alinir (Display
    Correction, exposure, LUT, denoiser dahil - VFB'de ne gorurseniz o).
  - Alpha istege bagli; kapaliyken PNG/TIF siyah zeminli kaydedilir.
  - Is bitince Render Setup, aktif viewport ve zaman cizelgesi eski haline doner.
================================================================================
*/

global PB_Roll
global PB_Open

fn PB_cmpName a b = ( stricmp a.name b.name )

fn PB_safe s =
(
	local bad = "\\/:*?\"<>| "
	local r = ""
	for i = 1 to s.count do
	(
		local ch = s[i]
		if findString bad ch != undefined then r += "_" else r += ch
	)
	r
)

fn PB_collectCams =
(
	local arr = for c in cameras where superClassOf c == camera collect c
	qsort arr PB_cmpName
	arr
)

fn PB_timeStr sec =
(
	local h = (sec / 3600) as integer
	local m = ((sec - h * 3600) / 60) as integer
	local s = (sec - h * 3600 - m * 60) as integer
	(formattedPrint h format:"02d") + ":" + (formattedPrint m format:"02d") + ":" + (formattedPrint s format:"02d")
)

-- PNG/TIF icindeki alpha'yi renklere dokunmadan kaldirir (siyah zemine yassilastirir).
fn PB_flatten f =
(
	local ext = toLower (getFilenameType f)
	if ext != ".png" and ext != ".tif" and ext != ".tiff" then false
	else
	(
		local bytes = (dotNetClass "System.IO.File").ReadAllBytes f
		local ms = dotNetObject "System.IO.MemoryStream" bytes
		local img = (dotNetClass "System.Drawing.Image").FromStream ms
		local w = img.Width
		local h = img.Height
		local bmp = dotNetObject "System.Drawing.Bitmap" w h (dotNetClass "System.Drawing.Imaging.PixelFormat").Format24bppRgb
		local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
		g.Clear (dotNetClass "System.Drawing.Color").Black
		g.DrawImage img 0 0 w h
		g.Dispose()
		img.Dispose()
		ms.Dispose()
		local fmt = if ext == ".png" then (dotNetClass "System.Drawing.Imaging.ImageFormat").Png else (dotNetClass "System.Drawing.Imaging.ImageFormat").Tiff
		bmp.Save f fmt
		bmp.Dispose()
		true
	)
)

fn PB_isVRay = ( matchPattern (renderers.production as string) pattern:"*V_Ray*" )

-- Tek kareyi aktif Render Setup ile (F9 ile ayni yol) render edip kaydeder.
-- V-Ray ise goruntu V-Ray VFB'den kaydedilir: VFB'de gordugunuzle birebir ayni
-- (Display Correction, exposure, LUT, denoiser vb. katmanlar dahil).
fn PB_renderOne outFile keepAlpha =
(
	local vr = PB_isVRay()
	rendTimeType = 1
	if vr then rendSaveFile = false
	else ( rendSaveFile = true; rendOutputFilename = outFile )
	max quick render
	if vr do vfbControl #saveimage outFile
	if not keepAlpha and doesFileExist outFile do ( try ( PB_flatten outFile ) catch ( format "[PRO Batch] alpha kaldirilamadi: %\n" (getCurrentException()) ) )
	doesFileExist outFile
)

-- Bir kamerayi render eder (tek kare ya da animasyon araligi, kare kare).
-- Donus: #(durum, sureSn, mesaj)  durum: #ok / #error
fn PB_renderCam c outFile animMode w h keepAlpha =
(
	local t0 = timeStamp()
	local st = #ok
	local msg = ""
	try
	(
		renderWidth = w
		renderHeight = h
		viewport.setCamera c
		try ( rendUseActiveView = true ) catch ()
		if not animMode then
		(
			if not (PB_renderOne outFile keepAlpha) do ( st = #error; msg = "dosya olusmadi" )
		)
		else
		(
			local base = (getFilenamePath outFile) + (getFilenameFile outFile)
			local ext = getFilenameType outFile
			for t = animationRange.start to animationRange.end do
			(
				sliderTime = t
				local fr = formattedPrint ((t as integer) / TicksPerFrame) format:"04d"
				if not (PB_renderOne (base + fr + ext) keepAlpha) do ( st = #error; msg = "kare " + fr + " olusmadi" )
			)
		)
	)
	catch
	(
		st = #error
		msg = getCurrentException()
		format "[PRO Batch] % hata: %\n" c.name msg
	)
	gc light:true
	#(st, (timeStamp() - t0) / 1000.0, msg)
)

-- Render Setup + aktif viewport durumunu sakla / geri yukle
fn PB_saveState =
(
	#(rendTimeType, rendSaveFile, rendOutputFilename, renderWidth, renderHeight, viewport.getType(), viewport.getCamera(), sliderTime)
)

fn PB_restoreState s =
(
	try ( rendTimeType = s[1] ) catch ()
	try ( rendSaveFile = s[2] ) catch ()
	try ( rendOutputFilename = s[3] ) catch ()
	try ( renderWidth = s[4]; renderHeight = s[5] ) catch ()
	try ( if s[7] != undefined and isValidNode s[7] then viewport.setCamera s[7] else viewport.setType s[6] ) catch ()
	try ( sliderTime = s[8] ) catch ()
)

try ( destroyDialog PB_Roll ) catch ()

rollout PB_Roll "PRO Batch v0.2 - Gece Render" width:340
(
	local camNodes = #()

	group "Kameralar"
	(
		multiListBox lbCams "" height:12
		button btnRefresh "Yenile" width:100 across:3
		button btnAll "Tumunu Sec" width:100
		button btnNone "Hicbiri" width:100
		label lblCount "" align:#left
	)

	group "Cikti"
	(
		edittext etDir "Klasor" width:270 across:2
		button btnDir "..." width:30 align:#right
		edittext etPrefix "Dosya on eki" width:200 align:#left
		dropdownlist ddlFmt "Format" items:#("png", "jpg", "exr", "tif", "tga") width:80 align:#left
		label lblInfo "Render: aktif Render Setup. Kayit: V-Ray VFB (VFB'de ne gorurseniz o)." align:#left
		checkbox chkAlpha "Seffaf arka plani koru (alpha)" checked:false tooltip:"Kapaliyken PNG/TIF alpha'siz, siyah zeminli kaydedilir."
	)

	group "Cozunurluk ve Kareler"
	(
		checkbox chkRes "Cozunurlugu degistir" checked:false across:3
		spinner spW "G" range:[16,20000,1920] type:#integer fieldwidth:42
		spinner spH "Y" range:[16,20000,1080] type:#integer fieldwidth:42
		radiobuttons rdoFrames "" labels:#("Mevcut kare", "Animasyon araligi") default:1 columns:2 align:#left
	)

	group "Gece Modu"
	(
		checkbox chkLog "Rapor dosyasi yaz (PRO_Batch_rapor.txt)" checked:true
		checkbox chkShut "Is bitince bilgisayari kapat (5 dk sonra)" checked:false
	)

	button btnTest "Hizli Test  (ilk secili kamera, %25 cozunurluk)" width:320
	button btnRun "TUM SECILI KAMERALARI RENDER ET" width:320 height:36
	label lblStatus "Hazir." align:#left

	-- ------------------------------------------------------------ yardimci
	fn presetFile = ( (getDir #plugcfg) + "\\ProBatch.ini" )

	fn isValueCtrl c =
	(
		local k = classOf c
		k == CheckBoxControl or k == SpinnerControl or k == RadioControl or k == EditTextControl or k == ComboBoxControl
	)

	fn savePreset f =
	(
		for c in PB_Roll.controls where isValueCtrl c do
		(
			local k = classOf c
			local v = ""
			if k == CheckBoxControl then v = c.checked as string
			else if k == SpinnerControl then v = c.value as string
			else if k == RadioControl then v = c.state as string
			else if k == EditTextControl then v = c.text
			else if k == ComboBoxControl then v = c.selection as string
			setINISetting f "Settings" c.name v
		)
	)

	fn loadPreset f =
	(
		if doesFileExist f do
		(
			for c in PB_Roll.controls where isValueCtrl c do
			(
				local s = getINISetting f "Settings" c.name
				if s != "" do
				(
					local k = classOf c
					if k == CheckBoxControl then c.checked = (s == "true")
					else if k == SpinnerControl then c.value = s as float
					else if k == RadioControl then c.state = s as integer
					else if k == EditTextControl then c.text = s
					else if k == ComboBoxControl then c.selection = s as integer
				)
			)
		)
	)

	fn updateUI =
	(
		spW.enabled = chkRes.checked
		spH.enabled = chkRes.checked
		local n = lbCams.selection.numberSet
		lblCount.text = (camNodes.count as string) + " kamera bulundu, " + (n as string) + " secili."
	)

	fn refreshCams =
	(
		camNodes = PB_collectCams()
		lbCams.items = for c in camNodes collect (c.name + "   [" + ((classOf c) as string) + "]" + (if c.isHidden then "  (gizli)" else ""))
		lbCams.selection = if camNodes.count > 0 then #{1..camNodes.count} else #{}
		updateUI()
	)

	fn sceneBase =
	(
		local p = etPrefix.text
		if p == "" do
		(
			p = getFilenameFile maxFileName
			if p == "" do p = "Sahne"
		)
		PB_safe p
	)

	fn outPathFor c dir =
	(
		local nm = sceneBase() + "_" + (PB_safe c.name)
		if rdoFrames.state == 2 do nm += "_"
		dir + "\\" + nm + "." + ddlFmt.selected
	)

	fn ensureDir =
	(
		local d = etDir.text
		if d == "" do
		(
			d = (getDir #renderoutput) + "\\PRO_Batch"
			etDir.text = d
		)
		if not doesFileExist d do makeDir d all:true
		if doesFileExist d then d else undefined
	)

	-- ------------------------------------------------------------ olaylar
	on PB_Roll open do
	(
		loadPreset (presetFile())
		refreshCams()
	)
	on PB_Roll close do savePreset (presetFile())

	on btnRefresh pressed do refreshCams()
	on btnAll pressed do ( if camNodes.count > 0 do lbCams.selection = #{1..camNodes.count}; updateUI() )
	on btnNone pressed do ( lbCams.selection = #{}; updateUI() )
	on lbCams selectionEnd do updateUI()
	on chkRes changed s do updateUI()

	on btnDir pressed do
	(
		local d = getSavePath caption:"Render cikti klasoru" initialDir:(if etDir.text != "" then etDir.text else (getDir #renderoutput))
		if d != undefined do etDir.text = d
	)

	on btnTest pressed do
	(
		local idx = (lbCams.selection as array)
		if idx.count == 0 then messageBox "Once en az bir kamera secin." title:"PRO Batch"
		else
		(
			local d = ensureDir()
			if d == undefined then messageBox "Cikti klasoru olusturulamadi." title:"PRO Batch"
			else
			(
				local c = camNodes[idx[1]]
				if not isValidNode c then ( messageBox "Kamera sahnede yok, Yenile'ye basin." title:"PRO Batch" )
				else
				(
					local f = d + "\\_TEST_" + (PB_safe c.name) + "." + ddlFmt.selected
					local w = (renderWidth / 4) as integer
					local h = (renderHeight / 4) as integer
					lblStatus.text = "Test render: " + c.name
					local saved = PB_saveState()
					renderSceneDialog.close()
					local r = PB_renderCam c f false (amax w 16) (amax h 16) chkAlpha.checked
					PB_restoreState saved
					if r[1] == #ok then lblStatus.text = "Test tamam (" + (PB_timeStr r[2]) + "): " + f
					else lblStatus.text = "Test basarisiz: " + (r[1] as string) + " - Listener'a bakin."
				)
			)
		)
	)

	on btnRun pressed do
	(
		local idx = (lbCams.selection as array)
		if idx.count == 0 then messageBox "Once en az bir kamera secin." title:"PRO Batch"
		else
		(
			local d = ensureDir()
			if d == undefined then messageBox "Cikti klasoru olusturulamadi." title:"PRO Batch"
			else
			(
				savePreset (presetFile())
				local w = if chkRes.checked then spW.value else renderWidth
				local h = if chkRes.checked then spH.value else renderHeight
				local animMode = rdoFrames.state == 2
				local logF = undefined
				if chkLog.checked do
				(
					logF = createFile (d + "\\PRO_Batch_rapor.txt")
					format "PRO Batch raporu\nSahne: %\nBaslangic: %\nCozunurluk: %x%   Mod: %\nRenderer: %\n\n" (maxFilePath + maxFileName) localTime w h (if animMode then "animasyon" else "tek kare") (renderers.production as string) to:logF
					flush logF
				)

				local saved = PB_saveState()
				renderSceneDialog.close()
				local tAll = timeStamp()
				local okN = 0
				local errN = 0
				local stopped = false
				local i = 0
				for k in idx while not stopped do
				(
					i += 1
					local c = camNodes[k]
					if not isValidNode c then
					(
						errN += 1
						if logF != undefined do ( format "[ATLANDI] (silinmis kamera)\n" to:logF; flush logF )
					)
					else
					(
						local f = outPathFor c d
						lblStatus.text = "(" + (i as string) + "/" + (idx.count as string) + ") " + c.name
						local r = PB_renderCam c f animMode w h chkAlpha.checked
						if r[1] == #ok then
						(
							okN += 1
							if logF != undefined do ( format "[TAMAM] %  sure: %  ->  %\n" c.name (PB_timeStr r[2]) f to:logF; flush logF )
						)
						else if r[1] == #cancelled then
						(
							stopped = true
							if logF != undefined do ( format "[IPTAL] % (kullanici durdurdu, kuyruk kesildi)\n" c.name to:logF; flush logF )
						)
						else
						(
							errN += 1
							if logF != undefined do ( format "[HATA]  %  sure: %  (%)\n" c.name (PB_timeStr r[2]) r[3] to:logF; flush logF )
						)
					)
				)

				PB_restoreState saved
				local total = (timeStamp() - tAll) / 1000.0
				local summary = (okN as string) + " tamam, " + (errN as string) + " hata" + (if stopped then ", IPTAL EDILDI" else "") + ". Toplam: " + (PB_timeStr total)
				if logF != undefined do
				(
					format "\nBitis: %\nOzet: %\n" localTime summary to:logF
					close logF
				)
				lblStatus.text = summary

				if chkShut.checked and not stopped then
				(
					ShellLaunch "shutdown.exe" "/s /t 300 /c \"PRO Batch bitti. Iptal: shutdown /a\""
				)
				else
				(
					messageBox ("PRO Batch bitti.\n\n" + summary + "\n\nKlasor: " + d) title:"PRO Batch"
				)
			)
		)
	)
)

fn PB_Open = ( try ( destroyDialog PB_Roll ) catch (); createDialog PB_Roll )
PB_Open()
