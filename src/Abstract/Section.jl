# Export Sections API
export Sections,
       getindex, endof, length, start, next, done, eltype,
       find, findfirst,
       handle, header

# Export Section API
export Section,
       deref, contents, section_name, section_size, section_offset,
       section_address

# Export Datatypes
export SectionRef,
       read, seekstart, seek, eof, section_number

# Import Base methods for extension
import Base: read, seek, seekstart, eof, start, length, done, next, endof,
             eltype, find, findfirst

"""
    Sections

An abstraction over the concept of a collection of `Section` types within an
object file.  One can think of the `Sections` object containing the table of
section headers within the object file, whereas the `Section`/`SectionRef`
objects contain the actual section data itself.  The list of available API
operations is given below, with methods that subclasses must implement marked
in emphasis:

### Creation
  - *Sections()*

### Iteration
  - getindex()
  - *endof()*
  - length()
  - start()
  - next()
  - done()
  - eltype()

### Search
  - find()
  - findfirst()

### Misc.
  - *handle()*
"""
abstract type Sections{H<:ObjectHandle} end

# Fairly simple iteration interface specification
@mustimplement endof(sections::Sections)
start(sections::Sections) = 1
done(sections::Sections, idx) = idx > length(sections)
next(sections::Sections, idx) = (sections[idx], idx+1)
length(sections::Sections) = endof(sections)
eltype(::Type{S}) where {S <: Sections} = SectionRef

function getindex(sections::Sections, idx)
    # Punt off to `getindex_ref`
    oh = handle(sections)
    return getindex_ref(
        sections,
        section_header_offset(oh),
        section_header_size(oh),
        section_header_type(oh),
        SectionRef,
        idx
    )
end

"""
    find(sections::Sections, name::String)

Return a list of sections that match the given `name`.
"""
function find(sections::Sections, name::String)
    return find(sections, [name])
end

"""
    find(sections::Sections, name::String)

Return a list of sections that match one of the given `names`.
"""
function find(sections::Sections, names::Vector{String})
    return [s for s in sections if section_name(s) in names]
end

"""
    findfirst(sections::Sections, name::String)

Return the first section that matches the given `name`.
"""
function findfirst(sections::Sections, name::String)
    return findfirst(sections, [name])
end

"""
    findfirst(sections::Sections, names::Vector{String})

Return the first section that matches on of the given `names`.
"""
function findfirst(sections::Sections, names::Vector{String})
    results = find(sections, names)
    if isempty(results)
        error("Could not find any sections that match $(names)")
    end
    return first(results)
end


"""
    handle(sections::Sections)

Return the `ObjectHandle` that this `Sections` object belongs to
"""
@mustimplement handle(sections::Sections)



"""
    Section

An abstraction over the concept of a `Section` within an object file.  Because
many operations upon sections require global operations (access to the string
table, knowledge of position within the file, etc...) some operations are
defined only upon the `SectionRef` datatype.  As a user, the `SectionRef` type
should be the primary method of interacting with sections, as a developer
adding new object file formats, some methods must support `Section`s, others
must support only `SectionRef`s.  Note that any method that works on a
`Section` must also work with a `SectionRef`, see the `@derefmethod` macro for
a convenient helper macro to generate `SectionRef` -> `Section` wrapper
methods. The list of available API operations is given below, with methods that
subclasses must implement marked in emphasis:

### Creation:
  - *read()*

### Utility:
  - deref()

### IO-like operations:
  - contents()

### Format-specific properties:
  - *section_name()*
  - *section_size()*
  - *section_offset()*
  - *section_address()*
"""
abstract type Section{H<:ObjectHandle} end

deref(section::Section) = section
@mustimplement read(oh::ObjectHandle, ::Type{Section})

# """
#     position(section::Section)

# Return the position of a Section within a file
# """
# position(section::Section) = position(handle(x)) - section_offset(x)


# """
#     seek(oh::ObjectHandle, section::Section)

# Seek the given `ObjectHandle` to the beginning of `section`
# """
# function seek(oh::H, section::Section{T}) where {H <: ObjectHandle, T <: H}
#     return seek(oh, section_offset(section))
# end

"""
    contents(oh::ObjectHandle, section::Section)

Read the contents of the section referred to by `section` from the given
`ObjectHandle`, returning a `Vector{UInt8}`.
"""
function contents(oh::H, section::Section{H}) where {H<:ObjectHandle}
    # Seek to the section's location, then read it in!
    seek(oh, section_offset(section))
    return read(oh, size(section))
end


"""
    section_name(section::Section)

Return the name of the given section as a string.  In order to return a true
name, it is necessary to perform a lookup within the object's string table,
which cannot be done using just a `Section` object; use a `SectionRef` object
instead if you need that.  For sanity sake, this method will return a string,
but the contents of the string may be something like the offset within the
string table pointing to this `Section`'s name, e.g. "@strtab.123"
"""
@mustimplement section_name(section::Section)

"""
    section_size(section::Section)

The size of the actual data contained in the section. This should exclude any
padding mandated by the file format e.g. due to alignment rules
"""
@mustimplement section_size(section::Section)

"""
    section_offset(section::Section)

The offset of the section in the file, in bytes
"""
@mustimplement section_offset(section::Section)

"""
    section_address(section::Section)

The address of the section in virtual memory.
"""
@mustimplement section_address(section::Section)


"""
    SectionRef

Provides a reference to a `Section`, along with a reference to the
`ObjectHandle` this `Section` comes from.  This should be the primary method by
which users interact with sections inside object files.  The list of available
API operations is given below, with methods that subclasses must implement
marked in emphasis.  Note that this overlaps heavily with the `Section` object
API, this is by design as many of the methods are simply passthroughs to the
underlying `Section` API calls for ease of use.

### Creation:
  - *SectionRef()*

### Utility
  - *deref()*
  - *handle()*
  - *Sections()*

### IO-like operations:
  - read()
  - seekstart()
  - seek()
  - eof()


### Format-specific properties:
  - section_name()
  - *section_number()*
  - section_type()
  - section_size()
  - section_offset()
  - section_address()
"""
abstract type SectionRef{H<:ObjectHandle} end

"""
    SectionRef(sections::Sections, section::Section, idx)

Construct a `SectionRef` object pointing to the given `Section`, which itself
represents the `idx`'th section within the given `Sections`.
"""
@mustimplement SectionRef(sections::Sections, section::Section, idx)


"""
    deref(section::SectionRef)

Dereference the given `SectionRef` object to a `Section`.
"""
@mustimplement deref(section::SectionRef)

"""
    handle(section::SectionRef)

Return the `ObjectHandle` this `SectionRef` belongs to.  This method is
`SectionRef`-only.
"""
@mustimplement handle(section::SectionRef)

"""
    Sections(section::SectionRef)

Return the `Sections` collection this `section` belongs to.
"""
@mustimplement Sections(section::SectionRef)

"""
    section_number(section::SectionRef)

The index of the given section within the section header table.
"""
@mustimplement section_number(section::SectionRef)

@derefmethod section_name(section::SectionRef)
@derefmethod section_size(section::SectionRef)
@derefmethod section_offset(section::SectionRef)
@derefmethod section_address(section::SectionRef)



"""
    read(section::SectionRef)

Read the contents of the section referred to by `section`, returning a
`Vector{UInt8}`.
"""
function read(section::SectionRef)
    return read(handle(section), deref(section))
end

"""
    seekstart(section::SectionRef)

Seek to the beginning of `section` in the `ObjectHandle` it was loaded from.
"""
function seekstart(section::SectionRef)
    return seek(handle(section), section_offset(section))
end

"""
    seek(section::SectionRef, offset)

Seek to `offset` relative to `section` in the `ObjectHandle` that this
`SectionRef` refers to
"""
function seek(section::SectionRef, offset)
    return seek(handle(section), section_offset(section) + offset)
end

"""
    eof(section::SectionRef)

Returns `true` if the `ObjectHandle` that this `SectionRef` refers to has read
beyond the current section's extent
"""
function eof(section::SectionRef)
    # If the handle itself thinks it's an eof(), then yeah let's quit out
    if eof(handle(section))
        return true
    end

    # If we are beyond this section, then we also consider this the end of the
    # current section
    section_end = section_offset(section) + section_size(section)
    return position(handle(section)) >= section_end
end