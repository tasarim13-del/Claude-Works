/*
================================================================================
  PRO Slicer v0.1  -  3ds Max icin dilimleme + topoloji + LOD araci
================================================================================
  KURULUM / KULLANIM
  - 3ds Max > Scripting > Run Script... > ProSlicer.ms
    (ya da dosyayi viewport'a surukleyip birakin)
  - Kalici olsun isterseniz dosyayi su klasore kopyalayin:
      <3ds Max>\scripts\Startup\   (Max acilinca otomatik yuklenir)
    ve MAXScript Listener'a  PSOpen()  yazarak paneli acin.

  BOLUMLER
  1) Dilimleme   : Secili geometriyi X/Y/Z eksenlerinde kup grid'e boler,
                   her hucreyi ayri obje yapar, kesitleri kapatir (Cap).
  2) Temizlik    : Weld, yalniz vertex silme, normal birlestirme, auto smooth.
  3) Cikti (LOD) : _MID (temiz), _LP (ProOptimizer), _HP (Quadify+TurboSmooth).
                   LOD once uygulanir, SONRA dilimlenir -> parca sinirlari
                   birbirine tam oturur, catlak olusmaz.
  4) Spline->Mesh: Extrude'u Grid kapak + segment + Quadify ile kurar;
                   Bend/FFD/Twist gibi deformasyonlarda yuz kirilmasini onler.

  Ayarlar panel kapaninca otomatik kaydedilir (plugcfg\ProSlicer.ini).
  Tum islem tek adimda geri alinabilir (Ctrl+Z).
  Orijinal objeler degistirilmez; ciktilar PRO_Slicer_* katmanlarina gider.
================================================================================
*/

struct ProSlicerOpts
(
	doSlice, useCount, axes, counts, sizes, capHoles, gap,
	weld, delIso, unify, smooth, smoothAng,
	outMid, outLow, lowPct, protect, outHigh, highIt, highQuad, quadSize,
	hideSrc
)

struct ProSlicerCore
(
	-- Point3 bileseni (1=X, 2=Y, 3=Z)
	fn axVal p a =
	(
		if a == 1 then p.x
		else if a == 2 then p.y
		else p.z
	),

	fn getOutputLayer layerName =
	(
		local lay = LayerManager.getLayerFromName layerName
		if lay == undefined do lay = LayerManager.newLayerFromName layerName
		lay
	),

	-- Orijinale dokunmadan, transform'u gomulu Editable Poly kopyasi
	fn makeWorkCopy src =
	(
		local n = copy src
		n.parent = undefined
		n.name = src.name + "_work"
		resetXForm n
		convertToPoly n
		n
	),

	fn cleanMesh n weldThr delIso =
	(
		if weldThr > 0 do
		(
			n.weldThreshold = weldThr
			polyop.weldVertsByThreshold n #all
		)
		if delIso do polyop.deleteIsoVerts n
		n
	),

	-- LOW POLY: ProOptimizer (sinirlari koruyarak)
	fn applyLow n pct protect =
	(
		local m = ProOptimizer()
		addModifier n m
		try ( m.OptimizationMode = (if protect then 1 else 0) ) catch ()
		try ( m.KeepUV = true ) catch ()
		try ( m.KeepNormals = false ) catch ()
		m.VertexPercent = pct
		m.Calculate = true
		m.VertexPercent = pct
		convertToPoly n
		n
	),

	-- HIGH POLY: (opsiyonel) Quadify -> TurboSmooth
	fn applyHigh n iters useQuad qsize =
	(
		if useQuad do addModifier n (Quadify_Mesh quadsize:qsize)
		addModifier n (TurboSmooth iterations:iters)
		convertToPoly n
		n
	),

	-- Grid olcusu. Donus: #(bboxMin, hucreBoyutlari, hucreSayilari)
	fn gridInfo n useAxes counts sizes useCount =
	(
		local bmin = n.min
		local bmax = n.max
		local cnt = #(1, 1, 1)
		local cel = #(1.0, 1.0, 1.0)
		for a = 1 to 3 do
		(
			local e = (axVal bmax a) - (axVal bmin a)
			cel[a] = amax e 0.0001
			if useAxes[a] and e > 0.0001 do
			(
				if useCount then
				(
					cnt[a] = amax 1 counts[a]
					cel[a] = e / cnt[a]
				)
				else
				(
					cnt[a] = amax 1 ((ceil (e / sizes[a])) as integer)
					cel[a] = sizes[a]
				)
			)
		)
		#(bmin, cel, cnt)
	),

	fn axisIdx c a bmin cel cnt =
	(
		local i = (floor (((axVal c a) - (axVal bmin a)) / cel[a])) as integer
		if i < 0 do i = 0
		if i > cnt[a] - 1 do i = cnt[a] - 1
		i
	),

	fn capAll p =
	(
		local oe = polyop.getOpenEdges p
		if oe.numberSet > 0 do polyop.capHolesByEdge p oe
	),

	-- Tek eksende dilimle + ayir (+ her kesiti duz kapakla kapat)
	-- Donus: #(#(node, eksenIndeksi), ...)
	fn splitAxis n a bmin cel cnt capHoles =
	(
		local result = #()
		local dirs = #([1,0,0], [0,1,0], [0,0,1])
		in coordsys world
		(
			for i = 1 to (cnt[a] - 1) do
			(
				local v = (axVal bmin a) + i * cel[a]
				local p = if a == 1 then [v,0,0] else if a == 2 then [0,v,0] else [0,0,v]
				polyop.slice n #all (ray p dirs[a])
			)
		)
		local nf = polyop.getNumFaces n
		local fk = #()
		in coordsys world
		(
			for f = 1 to nf do fk[f] = axisIdx (polyop.getFaceCenter n f) a bmin cel cnt
		)
		local done = false
		while not done do
		(
			nf = polyop.getNumFaces n
			if nf == 0 or fk.count != nf then done = true
			else
			(
				local k = fk[1]
				local fs = #{}
				for f = 1 to nf where fk[f] == k do fs[f] = true
				if fs.numberSet == nf then
				(
					append result #(n, k)
					done = true
				)
				else
				(
					local tmpName = uniqueName "PS_tmp_"
					polyop.detachFaces n fs delete:true asNode:true name:tmpName
					local nn = getNodeByName tmpName
					if nn != undefined do append result #(nn, k)
					fk = for f = 1 to fk.count where not fs[f] collect fk[f]
				)
			)
		)
		-- Beklenmedik durum: kalan yuzler korunur
		local found = false
		for r in result where r[1] == n do found = true
		if not found and isValidNode n do
		(
			if polyop.getNumFaces n > 0 then append result #(n, 0) else delete n
		)
		if capHoles do for r in result do capAll r[1]
		result
	),

	-- 3 eksen kup grid. Donus: #(#(node, ix, iy, iz), ...)
	fn gridSplit n useAxes counts sizes useCount capHoles =
	(
		local info = gridInfo n useAxes counts sizes useCount
		local bmin = info[1]
		local cel = info[2]
		local cnt = info[3]
		local pieces = #(#(n, 0, 0, 0))
		for a = 1 to 3 where cnt[a] > 1 do
		(
			local nextP = #()
			for pc in pieces do
			(
				for r in (splitAxis pc[1] a bmin cel cnt capHoles) do
				(
					local idx = #(pc[2], pc[3], pc[4])
					idx[a] = r[2]
					append nextP #(r[1], idx[1], idx[2], idx[3])
				)
			)
			pieces = nextP
		)
		pieces
	),

	fn finishPiece p capHoles gap ix iy iz doSmooth ang lay =
	(
		if capHoles do capAll p
		if doSmooth do
		(
			addModifier p (Smooth autosmooth:true threshold:ang)
			convertToPoly p
		)
		CenterPivot p
		if gap > 0 do move p [ix * gap, iy * gap, iz * gap]
		lay.addNode p
		p
	),

	fn processNode src o =
	(
		local created = #()
		local base = makeWorkCopy src
		cleanMesh base o.weld o.delIso
		if o.unify do
		(
			addModifier base (Normalmodifier unify:true)
			convertToPoly base
		)

		-- Once LOD, sonra dilimleme (parca sinirlari birbirine oturur)
		local variants = #()
		if o.outMid do append variants #("_MID", copy base)
		if o.outLow do
		(
			local l = copy base
			applyLow l o.lowPct o.protect
			append variants #("_LP", l)
		)
		if o.outHigh do
		(
			local h = copy base
			applyHigh h o.highIt o.highQuad o.quadSize
			append variants #("_HP", h)
		)
		delete base

		for v in variants do
		(
			local n = v[2]
			local suffix = v[1]
			local lay = getOutputLayer ("PRO_Slicer" + suffix)
			local baseName = src.name + suffix
			if o.doSlice then
			(
				local pieces = gridSplit n o.axes o.counts o.sizes o.useCount o.capHoles
				for pc in pieces do
				(
					local p = pc[1]
					local nm = baseName + "_x" + ((pc[2]+1) as string) + "_y" + ((pc[3]+1) as string) + "_z" + ((pc[4]+1) as string)
					if getNodeByName nm != undefined do nm = uniqueName (nm + "_")
					p.name = nm
					finishPiece p false o.gap pc[2] pc[3] pc[4] o.smooth o.smoothAng lay
					append created p
				)
			)
			else
			(
				n.name = baseName
				finishPiece n false 0 0 0 0 o.smooth o.smoothAng lay
				append created n
			)
		)
		if o.hideSrc do hide src
		created
	),

	-- SPLINE -> deformasyona hazir mesh
	fn splineToMesh s amount segs gridCap useQuad qsize steps =
	(
		local n = copy s
		n.parent = undefined
		n.name = s.name + "_EXT"
		try ( n.steps = steps ) catch ()
		try ( n.optimize = false ) catch ()
		try ( n.adaptive = false ) catch ()
		local e = Extrude amount:amount segs:segs
		try ( e.capType = (if gridCap then 1 else 0) ) catch ()   -- 0=Morph, 1=Grid
		try ( e.output = 1 ) catch ()                              -- 1=Mesh
		addModifier n e
		if useQuad do addModifier n (Quadify_Mesh quadsize:qsize)
		convertToPoly n
		(getOutputLayer "PRO_Slicer_EXT").addNode n
		n
	),

	fn analyze n =
	(
		local t = copy n
		convertToPoly t
		local tri = 0
		local quad = 0
		local ngon = 0
		local nf = polyop.getNumFaces t
		for f = 1 to nf do
		(
			local d = polyop.getFaceDeg t f
			if d == 3 then tri += 1 else if d == 4 then quad += 1 else ngon += 1
		)
		local openE = (polyop.getOpenEdges t).numberSet
		local nv = polyop.getNumVerts t
		local iso = nv - (polyop.getVertsUsingFace t #all).numberSet
		delete t
		n.name + "\n   Yuz: " + nf as string + "  (Ucgen: " + tri as string + "  Quad: " + quad as string + "  N-gon: " + ngon as string + ")" + \
		"\n   Vertex: " + nv as string + "   Acik kenar: " + openE as string + "   Yalniz vertex: " + iso as string
	)
)

global PSCore = ProSlicerCore()
global ProSlicerRoll
global PSOpen

try ( destroyDialog ProSlicerRoll ) catch ()

rollout ProSlicerRoll "PRO Slicer v0.1" width:310
(
	group "1 - Dilimleme (3 eksen kup grid)"
	(
		checkbox chkSlice "Dilimlemeyi uygula" checked:true
		radiobuttons rdoMode "" labels:#("Hucre sayisi ile", "Hucre boyutu ile") default:1 columns:2 align:#left
		checkbox chkX "X ekseni" checked:true across:3
		checkbox chkY "Y ekseni" checked:true
		checkbox chkZ "Z ekseni" checked:true
		spinner spnCX "Sayi X" range:[1,100,2] type:#integer fieldwidth:28 across:3
		spinner spnCY "Y" range:[1,100,2] type:#integer fieldwidth:28
		spinner spnCZ "Z" range:[1,100,2] type:#integer fieldwidth:28
		spinner spnSX "Boy X" range:[0.001,1000000,10] type:#worldunits fieldwidth:40 across:3
		spinner spnSY "Y" range:[0.001,1000000,10] type:#worldunits fieldwidth:40
		spinner spnSZ "Z" range:[0.001,1000000,10] type:#worldunits fieldwidth:40
		checkbox chkCap "Kesit yuzlerini kapat (Cap)" checked:true
		spinner spnGap "Parca araligi (patlatma)" range:[0,1000000,0] type:#worldunits fieldwidth:50 align:#left
	)

	group "2 - Temizlik ve Topoloji"
	(
		spinner spnWeld "Weld esigi" range:[0,100,0.01] type:#worldunits scale:0.001 fieldwidth:50 align:#left
		checkbox chkIso "Yalniz kalan vertex'leri sil" checked:true
		checkbox chkUnify "Ters normalleri duzelt (Unify)" checked:true
		checkbox chkSmooth "Auto Smooth" checked:true across:2
		spinner spnSmooth "Aci" range:[0,180,30] fieldwidth:35
	)

	group "3 - Cikti (LOD)"
	(
		checkbox chkMid "Temiz - orijinal yogunluk  (_MID)" checked:false
		checkbox chkLow "Low poly  (_LP)" checked:true across:2
		spinner spnLowPct "Vertex %" range:[1,100,40] type:#integer fieldwidth:35
		checkbox chkProtect "Low: dis sinirlari koru" checked:true
		checkbox chkHigh "High poly  (_HP)" checked:true across:2
		spinner spnHighIt "Iterasyon" range:[1,4,2] type:#integer fieldwidth:30
		checkbox chkQuad "High: once Quadify" checked:true across:2 tooltip:"Bozuk/uyumsuz yuzleri duzenli quad agina cevirir, sonra TurboSmooth uygular."
		spinner spnQuad "Quad %" range:[0.1,50,4] fieldwidth:35
	)

	group "4 - Spline > Mesh (deformasyona hazir)"
	(
		spinner spnExAmt "Extrude miktari" range:[-1000000,1000000,10] type:#worldunits fieldwidth:55 align:#left
		spinner spnExSeg "Segment sayisi" range:[1,500,8] type:#integer fieldwidth:55 align:#left
		spinner spnSteps "Spline adimlari" range:[0,100,6] type:#integer fieldwidth:55 align:#left
		checkbox chkGrid "Grid kapak (Morph yerine)" checked:true
		checkbox chkExQuad "Quadify uygula" checked:true across:2
		spinner spnExQuad "Quad %" range:[0.1,50,3] fieldwidth:35
		button btnSpline "Secili Spline'lari Donustur" width:280
	)

	group "Genel"
	(
		checkbox chkHide "Islenen orijinalleri gizle" checked:true
		button btnAnalyze "Analiz Et" width:90 across:3
		button btnSave "Ayar Kaydet" width:90
		button btnLoad "Ayar Yukle" width:90
	)

	button btnRun "CALISTIR  (secili geometriler)" width:290 height:34
	label lblStatus "Hazir." align:#left

	-- ---------------------------------------------------------------- yardimci
	fn presetFile = ( (getDir #plugcfg) + "\\ProSlicer.ini" )

	fn updateUI =
	(
		local on1 = chkSlice.checked
		local byCount = rdoMode.state == 1
		for c in #(rdoMode, chkX, chkY, chkZ, chkCap, spnGap) do c.enabled = on1
		for c in #(spnCX, spnCY, spnCZ) do c.enabled = on1 and byCount
		for c in #(spnSX, spnSY, spnSZ) do c.enabled = on1 and (not byCount)
		spnLowPct.enabled = chkLow.checked
		chkProtect.enabled = chkLow.checked
		spnHighIt.enabled = chkHigh.checked
		chkQuad.enabled = chkHigh.checked
		spnQuad.enabled = chkHigh.checked and chkQuad.checked
		spnSmooth.enabled = chkSmooth.checked
		spnExQuad.enabled = chkExQuad.checked
	)

	fn savePreset f =
	(
		for c in ProSlicerRoll.controls where (classOf c == CheckBoxControl or classOf c == SpinnerControl or classOf c == RadioControl) do
		(
			local v = case classOf c of
			(
				CheckBoxControl: c.checked as string
				SpinnerControl: c.value as string
				RadioControl: c.state as string
				default: undefined
			)
			if v != undefined do setINISetting f "Settings" c.name v
		)
	)

	fn loadPreset f =
	(
		if doesFileExist f do
		(
			for c in ProSlicerRoll.controls where (classOf c == CheckBoxControl or classOf c == SpinnerControl or classOf c == RadioControl) do
			(
				local s = getINISetting f "Settings" c.name
				if s != "" do
				(
					case classOf c of
					(
						CheckBoxControl: c.checked = (s == "true")
						SpinnerControl: c.value = s as float
						RadioControl: c.state = s as integer
					)
				)
			)
		)
		updateUI()
	)

	fn gatherOpts =
	(
		ProSlicerOpts \
			doSlice:chkSlice.checked useCount:(rdoMode.state == 1) \
			axes:#(chkX.checked, chkY.checked, chkZ.checked) \
			counts:#(spnCX.value, spnCY.value, spnCZ.value) \
			sizes:#(spnSX.value, spnSY.value, spnSZ.value) \
			capHoles:chkCap.checked gap:spnGap.value \
			weld:spnWeld.value delIso:chkIso.checked unify:chkUnify.checked \
			smooth:chkSmooth.checked smoothAng:spnSmooth.value \
			outMid:chkMid.checked outLow:chkLow.checked lowPct:spnLowPct.value protect:chkProtect.checked \
			outHigh:chkHigh.checked highIt:spnHighIt.value highQuad:chkQuad.checked quadSize:spnQuad.value \
			hideSrc:chkHide.checked
	)

	-- ---------------------------------------------------------------- olaylar
	on ProSlicerRoll open do loadPreset (presetFile())
	on ProSlicerRoll close do savePreset (presetFile())

	on chkSlice changed s do updateUI()
	on rdoMode changed s do updateUI()
	on chkLow changed s do updateUI()
	on chkHigh changed s do updateUI()
	on chkQuad changed s do updateUI()
	on chkSmooth changed s do updateUI()
	on chkExQuad changed s do updateUI()

	on btnSave pressed do
	(
		local f = getSaveFileName caption:"PRO Slicer ayar setini kaydet" types:"Ayar seti (*.ini)|*.ini"
		if f != undefined do ( savePreset f; lblStatus.text = "Ayar kaydedildi: " + filenameFromPath f )
	)

	on btnLoad pressed do
	(
		local f = getOpenFileName caption:"PRO Slicer ayar seti yukle" types:"Ayar seti (*.ini)|*.ini"
		if f != undefined do ( loadPreset f; lblStatus.text = "Ayar yuklendi: " + filenameFromPath f )
	)

	on btnAnalyze pressed do
	(
		local txt = ""
		for s in selection where canConvertTo s Editable_Poly do txt += (PSCore.analyze s) + "\n\n"
		if txt == "" then messageBox "Analiz icin en az bir obje secin." title:"PRO Slicer"
		else
		(
			format "[PRO Slicer] Analiz\n%\n" txt
			messageBox txt title:"PRO Slicer - Topoloji Analizi"
		)
	)

	on btnSpline pressed do
	(
		local shp = for s in selection where superClassOf s == Shape collect s
		if shp.count == 0 then messageBox "Lutfen en az bir spline secin." title:"PRO Slicer"
		else
		(
			local made = #()
			undo "PRO Slicer - Spline" on
			(
				for s in shp do
				(
					try
					(
						append made (PSCore.splineToMesh s spnExAmt.value spnExSeg.value chkGrid.checked chkExQuad.checked spnExQuad.value spnSteps.value)
						if chkHide.checked do hide s
					)
					catch ( format "[PRO Slicer] % atlandi: %\n" s.name (getCurrentException()) )
				)
			)
			select (for m in made where isValidNode m collect m)
			lblStatus.text = (made.count as string) + " spline donusturuldu. Simdi dilimleyebilirsiniz."
		)
	)

	on btnRun pressed do
	(
		local sel = for s in selection where superClassOf s == GeometryClass and canConvertTo s Editable_Poly collect s
		if sel.count == 0 then messageBox "Lutfen en az bir geometri objesi secin." title:"PRO Slicer"
		else if not (chkMid.checked or chkLow.checked or chkHigh.checked) then
			messageBox "En az bir cikti turu secin (_MID / _LP / _HP)." title:"PRO Slicer"
		else
		(
			local o = gatherOpts()
			local prevMode = getCommandPanelTaskMode()
			local allNew = #()
			local errs = 0
			local t0 = timeStamp()
			undo "PRO Slicer" on
			(
				with redraw off
				(
					progressStart "PRO Slicer"
					for i = 1 to sel.count do
					(
						lblStatus.text = "Isleniyor: " + sel[i].name
						try ( join allNew (PSCore.processNode sel[i] o) )
						catch ( errs += 1; format "[PRO Slicer] % hata: %\n" sel[i].name (getCurrentException()) )
						progressUpdate (100.0 * i / sel.count)
					)
					progressEnd()
				)
			)
			try ( setCommandPanelTaskMode prevMode ) catch ()
			clearSelection()
			select (for n in allNew where isValidNode n collect n)
			local sec = (timeStamp() - t0) / 1000.0
			lblStatus.text = (allNew.count as string) + " parca olustu (" + (sec as string) + " sn)" + (if errs > 0 then ", " + errs as string + " hata - Listener'a bakin" else "")
			redrawViews()
		)
	)
)

fn PSOpen = ( try ( destroyDialog ProSlicerRoll ) catch (); createDialog ProSlicerRoll )
PSOpen()
