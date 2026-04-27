from sqlalchemy.orm import Session

from app.models.role import ROLE_POWER, RoleName, UserRole
from app.models.user import User


def get_user_roles(user: User) -> list[RoleName]:
    return [role.role for role in user.roles]


def get_primary_role(user: User) -> RoleName:
    roles = get_user_roles(user)

    if not roles:
        return RoleName.USER

    return max(roles, key=lambda role: ROLE_POWER.get(role, 0))


def get_role_power(role: RoleName) -> int:
    return ROLE_POWER.get(role, 0)


def can_act_on(actor: User, target: User) -> bool:
    actor_role = get_primary_role(actor)
    target_role = get_primary_role(target)

    return get_role_power(actor_role) > get_role_power(target_role)


def is_founder_owner(user: User) -> bool:
    return get_primary_role(user) == RoleName.FOUNDER_OWNER


def is_owner_or_above(user: User) -> bool:
    return get_primary_role(user) in {
        RoleName.FOUNDER_OWNER,
        RoleName.OWNER,
    }


def is_staff_or_official(user: User) -> bool:
    return get_primary_role(user) != RoleName.USER


def can_assign_role(actor: User, target: User, new_role: RoleName) -> bool:
    actor_role = get_primary_role(actor)

    # Founder Owner is the only one who can assign Owner or Founder Owner level roles.
    if new_role in {RoleName.FOUNDER_OWNER, RoleName.OWNER}:
        return actor_role == RoleName.FOUNDER_OWNER

    # Owner can assign roles below Owner.
    if actor_role == RoleName.OWNER:
        return get_role_power(new_role) < get_role_power(RoleName.OWNER)

    # SuperAdmin can assign lower operational roles only.
    if actor_role == RoleName.SUPERADMIN:
        return get_role_power(new_role) < get_role_power(RoleName.SUPERADMIN)

    return False


def assign_role(
    db: Session,
    user: User,
    role: RoleName,
    assigned_by_user_id: int | None = None,
    reason: str | None = None,
) -> UserRole:
    existing = (
        db.query(UserRole)
        .filter(UserRole.user_id == user.id, UserRole.role == role)
        .first()
    )

    if existing:
        return existing

    user_role = UserRole(
        user_id=user.id,
        role=role,
        assigned_by_user_id=assigned_by_user_id,
        reason=reason,
    )

    db.add(user_role)
    db.commit()
    db.refresh(user_role)

    return user_role


def assign_role_checked(
    db: Session,
    actor: User,
    target: User,
    role: RoleName,
    reason: str | None = None,
) -> UserRole:
    from fastapi import HTTPException

    if not can_assign_role(actor, target, role):
        raise HTTPException(
            status_code=403,
            detail="You are not allowed to assign this role.",
        )

    # Nobody except Founder Owner can modify Founder Owner.
    if get_primary_role(target) == RoleName.FOUNDER_OWNER and get_primary_role(actor) != RoleName.FOUNDER_OWNER:
        raise HTTPException(
            status_code=403,
            detail="Founder Owner cannot be modified.",
        )

    return assign_role(
        db=db,
        user=target,
        role=role,
        assigned_by_user_id=actor.id,
        reason=reason,
    )