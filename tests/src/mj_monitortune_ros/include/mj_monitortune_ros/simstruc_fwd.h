/* Copyright 2023 The MathWorks, Inc. */

/*
 *   Forward definition of the SimStruct type. Important that this is not
 *   included by simstruc_types.h, because that file is included by
 *   System Object code that uses a different definition of SimStruct.
 */

#ifndef __SIMSTRUC_FWD_H__
#define __SIMSTRUC_FWD_H__

#ifndef _SIMSTRUCT
#define _SIMSTRUCT
/*
 * Use incomplete type for function prototypes within SimStruct itself
 */
typedef struct SimStruct_tag SimStruct;
#endif

#endif /* __SIMSTRUC_FWD_H__ */
