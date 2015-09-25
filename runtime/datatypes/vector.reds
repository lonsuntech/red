Red/System [
	Title:   "Vector! datatype runtime functions"
	Author:  "Nenad Rakocevic"
	File: 	 %vector.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2015 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

vector: context [
	verbose: 0
	
	rs-length?: func [
		vec 	[red-vector!]
		return: [integer!]
	][
		_series/get-length as red-series! vec no
	]
	
	rs-skip: func [
		vec 	[red-vector!]
		len		[integer!]
		return: [logic!]
	][
		_series/rs-skip as red-series! vec len
	]
	
	rs-next: func [
		vec 	[red-vector!]
		return: [logic!]
		/local
			s [series!]
	][
		_series/rs-skip as red-series! vec 1
	]
	
	rs-head: func [
		vec	    [red-vector!]
		return: [byte-ptr!]
		/local
			s [series!]
	][
		s: GET_BUFFER(vec)
		(as byte-ptr! s/offset) + (vec/head << (log-b GET_UNIT(s)))
	]
	
	rs-tail: func [
		vec	    [red-vector!]
		return: [byte-ptr!]
		/local
			s [series!]
	][
		s: GET_BUFFER(vec)
		as byte-ptr! s/tail
	]

	rs-tail?: func [
		vec	    [red-vector!]
		return: [logic!]
		/local
			s [series!]
	][
		s: GET_BUFFER(vec)
		(as byte-ptr! s/offset) + (vec/head << (log-b GET_UNIT(s))) >= as byte-ptr! s/tail
	]

	rs-clear: func [
		vec [red-vector!]
		/local
			s [series!]
	][
		s: GET_BUFFER(vec)
		s/tail: as cell! (as byte-ptr! s/offset) + (vec/head << (log-b GET_UNIT(s)))
	]
	
	rs-append-int: func [
		vec		[red-vector!]
		n		[integer!]
		/local
			s	 [series!]
			p	 [byte-ptr!]
			p4	 [int-ptr!]
	][
		s: GET_BUFFER(vec)
		p: alloc-tail-unit s 4		
		p4: as int-ptr! p
		p4/value: n
	]
	
	rs-append: func [
		vec		[red-vector!]
		value	[red-value!]
		return: [red-value!]
		/local
			s	 [series!]
			p	 [byte-ptr!]
			unit [integer!]
	][
		if vec/type <> TYPE_OF(value) [
			fire [TO_ERROR(script invalid-arg) value]
		]

		assert TYPE_OF(value) = vec/type
		s: GET_BUFFER(vec)
		unit: GET_UNIT(s)
		p: alloc-tail-unit s unit
		set-value p value unit
		value
	]
	
	rs-insert: func [
		vec		[red-vector!]
		offset	[integer!]								;-- offset from head in elements
		value	[red-value!]
		return: [series!]
		/local
			s	  [series!]
			p	  [byte-ptr!]
			unit  [integer!]
			unit2 [integer!]
	][
		if vec/type <> TYPE_OF(value) [
			fire [TO_ERROR(script invalid-arg) value]
		]

		s: GET_BUFFER(vec)
		unit: GET_UNIT(s)
		unit2: unit

		if ((as byte-ptr! s/tail) + unit2) > ((as byte-ptr! s + 1) + s/size) [
			s: expand-series s 0
		]
		p: (as byte-ptr! s/offset) + (offset << (log-b unit))

		move-memory										;-- make space
			p + unit2
			p
			as-integer (as byte-ptr! s/tail) - p

		s/tail: as cell! (as byte-ptr! s/tail) + unit2

		set-value p value unit
		s
	]

	get-value-int: func [
		p		[int-ptr!]
		unit	[integer!]
		return: [integer!]
	][
		switch unit [
			1 [p/value and FFh]
			2 [p/value and FFFFh]
			4 [p/value]
		]
	]

	get-value-float: func [
		p		[byte-ptr!]
		unit	[integer!]
		return: [float!]
		/local
			pf	 [pointer! [float!]]
			pf32 [pointer! [float32!]]
	][
		either unit = 4 [
			pf32: as pointer! [float32!] p
			as-float pf32/value
		][
			pf: as pointer! [float!] p
			pf/value
		]
	]

	get-value: func [
		p		[byte-ptr!]
		unit	[integer!]
		type	[integer!]
		return: [red-value!]
		/local
			int    [red-integer!]
			float  [red-float!]
	][
		switch type [
			TYPE_CHAR
			TYPE_INTEGER [
				int: as red-integer! stack/push*
				int/header: type
				int/value: get-value-int as int-ptr! p unit
				as red-value! int				
			]
			TYPE_FLOAT [
				float: as red-float! stack/push*
				float/header: TYPE_FLOAT
				float/value: get-value-float p unit
				as red-value! float
			]
		]
	]

	set-value: func [
		p		[byte-ptr!]
		value	[red-value!]
		unit	[integer!]
		/local
			int  [red-integer!]
			f	 [red-float!]
			p4	 [int-ptr!]
			pf	 [pointer! [float!]]
			pf32 [pointer! [float32!]]
	][
		switch TYPE_OF(value) [
			TYPE_CHAR
			TYPE_INTEGER [ 			;-- char! and integer! structs are overlapping
				int: as red-integer! value
				p4: as int-ptr! p
				p4/value: switch unit [
					1 [int/value and FFh or (p4/value and FFFFFF00h)]
					2 [int/value and FFFFh or (p4/value and FFFF0000h)]
					4 [int/value]
				]
			]
			TYPE_FLOAT [
				f: as red-float! value
				either unit = 8 [
					pf: as pointer! [float!] p
					pf/value: f/value
				][
					pf32: as pointer! [float32!] p
					pf32/value: as float32! f/value
				]
			]
			default [
				fire [TO_ERROR(script invalid-type) datatype/push TYPE_OF(value)]
			]
		]
	]
	
	append-values: func [
		vec	[red-vector!]
		blk [red-block!]
		/local
			value [red-value!]
			tail  [red-value!]
	][
		value: block/rs-head blk
		tail:  block/rs-tail blk
		
		while [value < tail][
			rs-append vec value
			value: value + 1
		]
	]
	
	serialize: func [
		vec		[red-vector!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part	[integer!]
		mold?	[logic!]
		return: [integer!]
		/local
			s		[series!]
			p		[byte-ptr!]
			end		[byte-ptr!]
			unit	[integer!]
			pf		[pointer! [float!]]
			pf32	[pointer! [float32!]]
			formed	[c-string!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/serialize"]]

		s: GET_BUFFER(vec)
		unit: GET_UNIT(s)
		p: (as byte-ptr! s/offset) + (vec/head << (log-b unit))
		end: as byte-ptr! s/tail

		while [p < end][
			if all [OPTION?(arg) part <= 0][return part]

			either vec/type = TYPE_CHAR [
				part: either mold? [
					string/concatenate-literal buffer {#"}
					string/append-escaped-char
							buffer
							get-value-int as int-ptr! p unit
							string/ESC_CHAR
							all?
					string/append-char GET_BUFFER(buffer) as-integer #"^""
					part - 4
				][
					string/append-escaped-char
							buffer
							get-value-int as int-ptr! p unit
							string/ESC_CHAR
							all?
					part - 1
				]
			][
				either vec/type = TYPE_FLOAT [
					formed: either unit = 8 [
						pf: as pointer! [float!] p
						float/form-float pf/value float/FORM_FLOAT_64
					][
						pf32: as pointer! [float32!] p
						float/form-float as-float pf32/value float/FORM_FLOAT_32
					]
				][
					formed: integer/form-signed get-value-int as int-ptr! p unit
				]
				string/concatenate-literal buffer formed
				part: part - system/words/length? formed	;@@ optimize by removing length?
			]
			if p + unit < end [
				string/append-char GET_BUFFER(buffer) as-integer space
				part: part - 1
			]
			p: p + unit
		]
		part	
	]

	do-math-scalar: func [
		op		[math-op!]
		left	[red-vector!]
		right	[red-value!]
		return: [red-value!]
		/local
			type	[integer!]
			s		[series!]
			unit	[integer!]
			len		[integer!]
			v1		[integer!]
			v2		[integer!]
			i		[integer!]
			p		[byte-ptr!]
			p4		[int-ptr!]
			f1		[float!]
			f2		[float!]
			pf		[pointer! [float!]]
			pf32	[pointer! [float32!]]
			int		[red-integer!]
			fl		[red-float!]
	][
		type: TYPE_OF(right)
		if all [
			type <> TYPE_INTEGER
			type <> TYPE_FLOAT
		][
			fire [TO_ERROR(script invalid-type) datatype/push type]
		]

		s: GET_BUFFER(left)
		unit: GET_UNIT(s)
		len: rs-length? left
		p: (as byte-ptr! s/offset) + (left/head << (log-b unit))
		i: 0
		either left/type = TYPE_FLOAT [
			either type = TYPE_FLOAT [
				fl: as red-float! right
				f2: fl/value
			][
				int: as red-integer! right
				f2: integer/to-float int/value
			]
			while [i < len][
				f1: get-value-float p unit
				f1: switch op [
					OP_ADD [f1 + f2]
					OP_SUB [f1 - f2]
					OP_MUL [f1 * f2]
					OP_REM [f1 % f2]
					OP_DIV [
						either 0.0 = f2 [
							fire [TO_ERROR(math zero-divide)]
							0.0								;-- pass the compiler's type-checking
						][
							f1 / f2
						]
					]
					default [
						fire [TO_ERROR(script invalid-type) datatype/push left/type]
						0.0
					]
				]
				either unit = 8 [
					pf: as pointer! [float!] p
					pf/value: f1
				][
					pf32: as pointer! [float32!] p
					pf32/value: as float32! f1
				]
				i:  i  + 1
				p:  p  + unit
			]
		][
			either type = TYPE_INTEGER [
				int: as red-integer! right
				v2: int/value
			][
				fl: as red-float! right
				f1: fl/value
				v2: float/to-integer either f1 < 0.0 [f1 + 0.4999999999999999][f1 - 0.4999999999999999]
			]
			while [i < len][
				v1: get-value-int as int-ptr! p unit
				v1: switch op [
					OP_ADD [v1 + v2]
					OP_SUB [v1 - v2]
					OP_MUL [v1 * v2]
					OP_REM [v1 % v2]
					OP_AND [v1 and v2]
					OP_OR  [v1 or v2]
					OP_XOR [v1 xor v2]
					OP_DIV [
						either zero? v2 [
							fire [TO_ERROR(math zero-divide)]
							0								;-- pass the compiler's type-checking
						][
							v1 / v2
						]
					]
				]
				switch unit [
					1 [p/value: as-byte v1]
					2 [p/1: as-byte v1 p/2: as-byte v1 >> 8]
					4 [p4: as int-ptr! p p4/value: v1]
				]
				i:  i  + 1
				p:  p  + unit
			]
		]
		as red-value! left
	]

	do-math: func [
		type		[math-op!]
		return:		[red-value!]
		/local
			left	[red-vector!]
			right	[red-vector!]
			s1		[series!]
			s2		[series!]
			unit	[integer!]
			unit1	[integer!]
			unit2	[integer!]
			len1	[integer!]
			len2	[integer!]
			v1		[integer!]
			v2		[integer!]
			i		[integer!]
			node	[node!]
			buffer	[series!]
			p		[byte-ptr!]
			p1		[byte-ptr!]
			p2		[byte-ptr!]
			p4		[int-ptr!]
			f1		[float!]
			f2		[float!]
			pf		[pointer! [float!]]
			pf32	[pointer! [float32!]]
	][
		left: as red-vector! stack/arguments
		right: left + 1

		if TYPE_OF(right) <> TYPE_VECTOR [
			return do-math-scalar type left as red-value! right
		]

		if left/type <> right/type [fire [TO_ERROR(script not-same-type)]]

		s1: GET_BUFFER(left)
		s2: GET_BUFFER(right)
		unit1: GET_UNIT(s1)
		unit2: GET_UNIT(s2)
		unit: either unit1 > unit2 [unit1][unit2]

		len1: rs-length? left
		len2: rs-length? right
		if len1 > len2 [len1: len2]

		p1: (as byte-ptr! s1/offset) + (left/head << (log-b unit1))
		p2: (as byte-ptr! s2/offset) + (right/head << (log-b unit2))

		node: alloc-bytes len1 << (log-b unit)
		buffer: as series! node/value
		buffer/flags: buffer/flags and flag-unit-mask or unit
		buffer/tail: as cell! (as byte-ptr! buffer/offset) + (len1 << (log-b unit))

		i: 0
		p:  as byte-ptr! buffer/offset
		either left/type = TYPE_FLOAT [
			while [i < len1][
				f1: get-value-float p1 unit1
				f2: get-value-float p2 unit2
				f1: switch type [
					OP_ADD [f1 + f2]
					OP_SUB [f1 - f2]
					OP_MUL [f1 * f2]
					OP_REM [f1 % f2]
					OP_DIV [
						either 0.0 = f2 [
							fire [TO_ERROR(math zero-divide)]
							0.0								;-- pass the compiler's type-checking
						][
							f1 / f2
						]
					]
					default [
						fire [TO_ERROR(script invalid-type) datatype/push left/type]
						0.0
					]
				]
				either unit = 8 [
					pf: as pointer! [float!] p
					pf/value: f1
				][
					pf32: as pointer! [float32!] p
					pf32/value: as float32! f1
				]
				i:  i  + 1
				p:  p  + unit
				p1: p1 + unit1
				p2: p2 + unit2
			]
		][
			while [i < len1][
				v1: get-value-int as int-ptr! p1 unit1
				v2: get-value-int as int-ptr! p2 unit2
				v1: switch type [
					OP_ADD [v1 + v2]
					OP_SUB [v1 - v2]
					OP_MUL [v1 * v2]
					OP_REM [v1 % v2]
					OP_AND [v1 and v2]
					OP_OR  [v1 or v2]
					OP_XOR [v1 xor v2]
					OP_DIV [
						either zero? v2 [
							fire [TO_ERROR(math zero-divide)]
							0								;-- pass the compiler's type-checking
						][
							v1 / v2
						]
					]
				]
				switch unit [
					1 [p/value: as-byte v1]
					2 [p/1: as-byte v1 p/2: as-byte v1 >> 8]
					4 [p4: as int-ptr! p p4/value: v1]
				]
				i:  i  + 1
				p:  p  + unit
				p1: p1 + unit1
				p2: p2 + unit2
			]
		]
		left/node: node
		left/head: 0
		as red-value! left
	]
	
	clone: func [
		vec		[red-vector!]							;-- clone the vector in-place
		return: [red-vector!]
		/local
			new    [node!]
			s	   [series!]
			target [series!]
			size   [integer!]
	][
		s: GET_BUFFER(vec)
		size: s/size									;-- @@ head position ignored
		new: alloc-bytes size
		
		unless zero? size [
			target: as series! new/value
			copy-memory
				as byte-ptr! target/offset
				as byte-ptr! s/offset
				size
			target/tail: as cell! ((as byte-ptr! target/offset) + size)
		]
		vec/node: new
		vec
	]
	
	push: func [
		vec [red-vector!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/push"]]

		copy-cell as red-value! vec stack/push*
	]
	
	make-at: func [
		slot	[red-value!]
		size	[integer!]
		type	[integer!]
		unit	[integer!]
		return: [red-vector!]
		/local
			vec [red-vector!]
			s	[series!]
	][
		vec: as red-vector! slot
		vec/header: TYPE_VECTOR							;-- implicit reset of all header flags
		vec/head: 	0
		vec/node: 	alloc-bytes size * unit
		vec/type:	type
		
		s: GET_BUFFER(vec)
		s/flags: s/flags and flag-unit-mask or unit
		vec
	]

	;--- Actions ---
	
	make: func [
		proto	[red-value!]
		spec	[red-value!]
		return:	[red-vector!]
		/local
			s	  [series!]
			w	  [red-word!]
			vec	  [red-vector!]
			int	  [red-integer!]
			value [red-value!]
			sym   [integer!]
			size  [integer!]
			blk-sz [integer!]
			unit  [integer!]
			type  [integer!]
			fill? [logic!]
			end   [byte-ptr!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/make"]]

		fill?: yes
		size: 0
		unit: 0
		type: TYPE_OF(spec)
		
		switch type [
			TYPE_INTEGER [
				int: as red-integer! spec
				size: int/value
			]
			TYPE_BLOCK [
				size:  block/rs-length? as red-block! spec
				either zero? size [
					type: TYPE_INTEGER
				][
					value: block/rs-head as red-block! spec
					type:  TYPE_OF(value)
					if type = TYPE_WORD [
						if size < 2 [
							fire [TO_ERROR(script bad-make-arg) proto spec]
						]

						;-- data type
						w: as red-word! value
						sym: symbol/resolve w/symbol
						type: case [
							sym = words/integer!	[TYPE_INTEGER]
							sym = words/char!		[TYPE_CHAR]
							sym = words/float!		[TYPE_FLOAT]
							true					[
								fire [TO_ERROR(script bad-make-arg) proto spec]
								0
							]
						]

						;-- bit size
						block/rs-next as red-block! spec
						value: block/rs-head as red-block! spec
						int: as red-integer! value
						unit: int/value >> 3
						unless any [unit = 4 unit = 2 unit = 1 unit = 8][
							fire [TO_ERROR(script bad-make-arg) proto spec]
						]

						;-- size or block values
						block/rs-next as red-block! spec
						value: block/rs-head as red-block! spec
						either TYPE_OF(value) = TYPE_INTEGER [
							int: as red-integer! value
							size: int/value
							either block/rs-next as red-block! spec [
								spec: value
							][
								spec: block/rs-head as red-block! spec
							]
						][
							either TYPE_OF(value) = TYPE_BLOCK [
								spec: value
								size: block/rs-length? as red-block! spec
							][
								fire [TO_ERROR(script invalid-spec-field) spec]
							]
						]
					]
					if zero? unit [
						unit:  switch type [
							TYPE_CHAR
							TYPE_INTEGER [size? integer!]
							TYPE_FLOAT	 [size? float!]
							default [
								fire [TO_ERROR(script invalid-type) datatype/push type]
								0
							]
						]
					]
				]
			]
			default [--NOT_IMPLEMENTED--]
		]

		if TYPE_OF(spec) = TYPE_BLOCK [
			blk-sz: block/rs-length? as red-block! spec
			if blk-sz >= size [size: blk-sz fill?: no]
		]
		if size <= 0 [fill?: no size: 1]
		if zero? unit [unit: 4]
		vec: make-at stack/push* size type unit

		if TYPE_OF(spec) = TYPE_BLOCK [
			append-values vec as red-block! spec
		]
		if fill? [
			s: GET_BUFFER(vec)
			end: (as byte-ptr! s/offset) + (size * unit)
			fill as byte-ptr! s/tail end null
			s/tail: as cell! end
		]
		vec
	]
	
	form: func [
		vec		[red-vector!]
		buffer	[red-string!]
		arg		[red-value!]
		part 	[integer!]
		return: [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/form"]]
		
		serialize vec buffer no no no arg part no
	]
	
	mold: func [
		vec		[red-vector!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part	[integer!]
		indent	[integer!]
		return:	[integer!]
		/local
			formed [c-string!]
			s	   [series!]
			unit   [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/mold"]]
		
		string/concatenate-literal buffer "make vector! ["
		part: part - 14

		s: GET_BUFFER(vec)
		unit: GET_UNIT(s)
		
		either any [
			all [unit = 4 any [vec/type = TYPE_CHAR vec/type = TYPE_INTEGER]]
			all [unit = 8 vec/type = TYPE_FLOAT]
		][
			part: serialize vec buffer only? all? flat? arg part yes
			string/append-char GET_BUFFER(buffer) as-integer #"]"
			part - 1
		][
			string/concatenate-literal buffer switch vec/type [
				TYPE_CHAR		[part: part - 5 "char!"]
				TYPE_INTEGER	[part: part - 8 "integer!"]
				TYPE_FLOAT		[part: part - 6 "float!"]
			]
			string/append-char GET_BUFFER(buffer) as-integer space

			formed: integer/form-signed unit << 3
			string/concatenate-literal buffer formed
			string/append-char GET_BUFFER(buffer) as-integer space
			part: part - system/words/length? formed

			string/append-char GET_BUFFER(buffer) as-integer #"["
			part: part - 4									;-- 3 spaces + "["

			part: serialize vec buffer only? all? flat? arg part yes

			string/concatenate-literal buffer "]]"
			part - 2
		]
	]

	compare: func [
		vec1	[red-vector!]
		vec2	[red-vector!]
		op		[integer!]
		return:	[integer!]
		/local
			s1		[series!]
			s2		[series!]
			unit	[integer!]
			unit1	[integer!]
			unit2	[integer!]
			type	[integer!]
			len1	[integer!]
			len2	[integer!]
			v1		[integer!]
			v2		[integer!]
			end 	[byte-ptr!]
			p1		[byte-ptr!]
			p2		[byte-ptr!]
			f1		[float!]
			f2		[float!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/compare"]]

		if TYPE_OF(vec2) <> TYPE_VECTOR [RETURN_COMPARE_OTHER]
		if vec1/type <> vec2/type [fire [TO_ERROR(script not-same-type)]]
		
		s1: GET_BUFFER(vec1)
		s2: GET_BUFFER(vec2)
		unit1: GET_UNIT(s1)
		unit2: GET_UNIT(s2)
		len1: rs-length? vec1
		len2: rs-length? vec2

		end: as byte-ptr! s2/tail

		either len1 <> len2 [							;-- shortcut exit for different sizes
			if any [
				op = COMP_EQUAL op = COMP_STRICT_EQUAL op = COMP_NOT_EQUAL
			][return 1]

			if len2 > len1 [
				end: end - (len2 - len1 << (log-b unit2))
			]
		][
			if zero? len1 [return 0]					;-- shortcut exit for empty vector!
		]

		type: vec1/type
		p1: (as byte-ptr! s1/offset) + (vec1/head << (log-b unit1))
		p2: (as byte-ptr! s2/offset) + (vec2/head << (log-b unit2))

		switch type [
			TYPE_CHAR
			TYPE_INTEGER [
				until [
					v1: get-value-int as int-ptr! p1 unit1
					v2: get-value-int as int-ptr! p2 unit2
					p1: p1 + unit1
					p2: p2 + unit2
					any [
						v1 <> v2
						p2 >= end
					]
				]
				if v1 = v2 [v1: len1 v2: len2]
				SIGN_COMPARE_RESULT(v1 v2)
			]
			TYPE_FLOAT [
				until [
					f1: get-value-float p1 unit1
					f2: get-value-float p2 unit2
					p1: p1 + unit1
					p2: p2 + unit2
					any [
						v1 <> v2
						p2 >= end
					]
				]
				either f1 = f2 [
					SIGN_COMPARE_RESULT(len1 len2)
				][
					SIGN_COMPARE_RESULT(f1 f2)
				]
			]
		]
	]

	;--- Modifying actions ---
			
	insert: func [
		vec		 [red-vector!]
		value	 [red-value!]
		part-arg [red-value!]
		only?	 [logic!]
		dup-arg	 [red-value!]
		append?	 [logic!]
		return:	 [red-value!]
		/local
			src		  [red-block!]
			cell	  [red-value!]
			limit	  [red-value!]
			int		  [red-integer!]
			char	  [red-char!]
			sp		  [red-vector!]
			s		  [series!]
			s2		  [series!]
			dup-n	  [integer!]
			cnt		  [integer!]
			part	  [integer!]
			len		  [integer!]
			added	  [integer!]
			vec-type  [integer!]
			tail?	  [logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "vector/insert"]]

		dup-n: 1
		cnt:   1
		part: -1
		vec-type: vec/type

		if OPTION?(part-arg) [
			part: either TYPE_OF(part-arg) = TYPE_INTEGER [
				int: as red-integer! part-arg
				int/value
			][
				sp: as red-vector! part-arg
				unless all [
					TYPE_OF(sp) = TYPE_VECTOR
					sp/node = vec/node
				][
					fire [TO_ERROR(script invalid-part) part-arg]
				]
				sp/head + 1								;-- /head is 0-based
			]
		]
		if OPTION?(dup-arg) [
			int: as red-integer! dup-arg
			cnt: int/value
			if negative? cnt [return as red-value! vec]
			dup-n: cnt
		]

		s: GET_BUFFER(vec)
		tail?: any [
			(as-integer s/tail - s/offset) >> (log-b GET_UNIT(s)) = vec/head
			append?
		]

		while [not zero? cnt][							;-- /dup support
			either TYPE_OF(value) = TYPE_BLOCK [		;@@ replace it with: typeset/any-block?
				src: as red-block! value
				s2: GET_BUFFER(src)
				cell:  s2/offset + src/head
				limit: cell + block/rs-length? src
			][
				cell:  value
				limit: value + 1
			]
			added: 0
			
			while [all [cell < limit added <> part]][	;-- multiple values case
				if TYPE_OF(cell) <> vec-type [
					fire [TO_ERROR(script invalid-type) datatype/push TYPE_OF(cell)]
				]
				either tail? [
					rs-append vec cell
				][
					rs-insert vec vec/head + added cell
				]
				added: added + 1
				cell: cell + 1
			]
			cnt: cnt - 1
		]
		unless append? [
			added: added * dup-n
			vec/head: vec/head + added
			s: GET_BUFFER(vec)
			assert (as byte-ptr! s/offset) + (vec/head << (log-b GET_UNIT(s))) <= as byte-ptr! s/tail
		]
		as red-value! vec
	]

	add: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/add"]]
		do-math OP_ADD 
	]

	divide: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/divide"]]
		do-math OP_DIV
	]

	multiply: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/multiply"]]
		do-math OP_MUL
	]

	remainder: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/remainder"]]
		do-math OP_REM
	]

	subtract: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/subtract"]]
		do-math OP_SUB
	]

	and~: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/and~"]]
		do-math OP_AND
	]

	or~: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/or~"]]
		do-math OP_OR
	]

	xor~: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "vector/xor~"]]
		do-math OP_XOR
	]

	init: does [
		datatype/register [
			TYPE_VECTOR
			TYPE_STRING
			"vector!"
			;-- General actions --
			:make
			INHERIT_ACTION	;random
			null			;reflect
			null			;to
			:form
			:mold
			INHERIT_ACTION	;eval-path
			null			;set-path
			:compare
			;-- Scalar actions --
			null			;absolute
			:add
			:divide
			:multiply
			null			;negate
			null			;power
			:remainder
			null			;round
			:subtract
			null			;even?
			null			;odd?
			;-- Bitwise actions --
			:and~
			null			;complement
			:or~
			:xor~
			;-- Series actions --
			null			;append
			INHERIT_ACTION	;at
			INHERIT_ACTION	;back
			null			;change
			INHERIT_ACTION	;clear
			INHERIT_ACTION	;copy
			INHERIT_ACTION	;find
			INHERIT_ACTION	;head
			INHERIT_ACTION	;head?
			INHERIT_ACTION	;index?
			:insert
			INHERIT_ACTION	;length?
			INHERIT_ACTION	;next
			INHERIT_ACTION	;pick
			INHERIT_ACTION	;poke
			null			;put
			INHERIT_ACTION	;remove
			INHERIT_ACTION	;reverse
			INHERIT_ACTION	;select
			INHERIT_ACTION	;sort
			INHERIT_ACTION	;skip
			null			;swap
			INHERIT_ACTION	;tail
			INHERIT_ACTION	;tail?
			INHERIT_ACTION	;take
			null			;trim
			;-- I/O actions --
			null			;create
			null			;close
			null			;delete
			INHERIT_ACTION	;modify
			null			;open
			null			;open?
			null			;query
			null			;read
			null			;rename
			null			;update
			null			;write
		]
	]
]